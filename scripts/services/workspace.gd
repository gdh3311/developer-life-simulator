extends Node
## The virtual company's workspace: dedicated Git config and repositories.
## Node process execution still needs OS-level isolation before distribution.
##
## Everything lives under user://sandbox and the player only ever sees virtual paths:
##   sandbox/home/newhire/commerce-api     ->  ~/commerce-api                  (player working copy)
##   sandbox/remote/commerce-api.git        ->  nexora.dev:commerce/commerce-api.git  (origin)
##   sandbox/bot/commerce-api               ->  (hidden) teammates' clone used for their commits/merges
##   sandbox/ci/commerce-api                ->  /ci/commerce-api                (CI checkout)
## Host git config is ignored (GIT_CONFIG_NOSYSTEM + sandbox GIT_CONFIG_GLOBAL).

signal repo_changed
signal git_event(kind: String, detail: String)  # branch_created, switched, committed, pushed, synced
signal tests_finished(result: Dictionary)
signal main_updated  # a teammate (or a merge) moved origin/main

const ProcJob := preload("res://scripts/services/proc_job.gd")
const NPC_EMAILS := ["daniel@nexora.dev", "sophie@nexora.dev", "mina@nexora.dev", "alex@nexora.dev", "codehub@nexora.dev"]
const BOT_OPTION := "nexora-bot"

const V_HOME := "/home/newhire"
const V_REPO := "/home/newhire/commerce-api"
const V_ORIGIN := "nexora.dev:commerce/commerce-api.git"
const V_CI := "/ci/commerce-api"

const PROTECT_MAIN_HOOK := """#!/bin/sh
# Teammates' automation (merges from CodeHub) may update main.
i=0
while [ "$i" -lt "${GIT_PUSH_OPTION_COUNT:-0}" ]; do
  eval "opt=\\$GIT_PUSH_OPTION_$i"
  if [ "$opt" = "nexora-bot" ]; then exit 0; fi
  i=$((i+1))
done
while read old new ref; do
  if [ "$ref" = "refs/heads/main" ]; then
    echo "main 브랜치는 보호되어 있습니다. 작업 브랜치를 push한 뒤 CodeHub에서 PR로 병합하세요." >&2
    exit 1
  fi
done
"""

## Git subcommands the in-game terminal allows.
const GIT_ALLOWED := ["status", "add", "commit", "switch", "checkout", "branch", "log", "diff", "show",
	"push", "pull", "fetch", "merge", "rebase", "restore", "reset", "stash", "blame", "remote", "tag",
	"rm", "mv", "cherry-pick", "revert", "reflog", "shortlog", "grep", "ls-files", "rev-parse", "config",
	"help", "version", "clean", "describe", "whatchanged"]
const GIT_BLOCKED_OPTS := ["--exec-path", "--git-dir", "--work-tree", "--upload-pack",
	"--receive-pack", "--config-env", "--exec", "--global", "--system", "--file", "-f", "--namespace"]
const GIT_INTERACTIVE := ["-i", "--interactive", "-p", "--patch", "--edit", "-e"]

var root := ""
var home := ""
var repo := ""
var origin := ""
var bot := ""
var ci := ""
var gitconfig := ""
var is_ready := false
var branch := "main"
var _snap := {}
var _seen_commits := {}
var _node_ok := -1
var _bot_busy := false
var _ci_busy := false
var _player_git_busy := false
var _player_tests_running := 0
var active_jobs := 0
var restore_changed := false


func _ready() -> void:
	root = ProjectSettings.globalize_path("user://sandbox")
	home = root.path_join("home/newhire")
	repo = home.path_join("commerce-api")
	origin = root.path_join("remote/commerce-api.git")
	bot = root.path_join("bot/commerce-api")
	ci = root.path_join("ci/commerce-api")
	gitconfig = root.path_join("gitconfig")
	_isolate_environment()


## Child processes (git, node) only ever see the sandbox's configuration.
func _isolate_environment() -> void:
	for v in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_SSH",
			"GIT_SSH_COMMAND", "GIT_ASKPASS", "NODE_OPTIONS", "NODE_PATH"]:
		OS.unset_environment(v)
	OS.set_environment("GIT_CONFIG_NOSYSTEM", "1")
	OS.set_environment("GIT_CONFIG_GLOBAL", gitconfig)
	OS.set_environment("GIT_CEILING_DIRECTORIES", root.get_base_dir())
	OS.set_environment("GIT_EDITOR", "false")
	OS.set_environment("GIT_SEQUENCE_EDITOR", "false")
	OS.set_environment("GIT_MERGE_AUTOEDIT", "no")
	OS.set_environment("GIT_PAGER", "cat")
	OS.set_environment("GIT_TERMINAL_PROMPT", "0")
	OS.set_environment("NO_COLOR", "1")


# --- Virtual paths -----------------------------------------------------------

## Replaces every host path in text with its in-game equivalent.
func virtualize(text: String) -> String:
	var pairs := [[repo, V_REPO], [home, V_HOME], [origin, V_ORIGIN], [origin.trim_suffix(".git"), V_ORIGIN.trim_suffix(".git")],
		[ci, V_CI], [bot, "/srv/bot"], [root, "/sandbox"]]
	for p in pairs:
		var real: String = p[0]
		for variant in [real, real.replace("/", "\\"), real.replace("/", "\\\\")]:
			text = text.replacen(variant, p[1])
	return text.replace("file:////", "file:///")


## Maps a path typed by the player (virtual or relative) to a repo-relative path.
func devirtualize(path: String) -> String:
	for prefix in [V_REPO + "/", "~/commerce-api/", "./"]:
		if path.begins_with(prefix):
			return path.substr(prefix.length())
	if path == V_REPO or path == "~/commerce-api" or path == ".":
		return ""
	return path


# --- Setup ------------------------------------------------------------------

func exists() -> bool:
	return DirAccess.dir_exists_absolute(repo.path_join(".git"))


## Creates the company repositories on first run. Returns { ok, message }.
func prepare() -> Dictionary:
	var t := Thread.new()
	t.start(_prepare_sync)
	while t.is_alive():
		await get_tree().process_frame
	var result: Dictionary = t.wait_to_finish()
	is_ready = result["ok"]
	if is_ready:
		_snap = await _snapshot()
		branch = _snap["branch"]
		var saved: Dictionary = Game.state.get("workspace_checkpoint", {})
		restore_changed = not saved.is_empty() and (saved.get("head", "") != _snap["head"] or saved.get("branch", "") != branch or saved.get("remote_main", "") != _snap["remote"].get("main", ""))
	return result


func _prepare_sync() -> Dictionary:
	_write_gitconfig()
	if OS.execute("git", ["--version"]) != 0:
		return {"ok": false, "message": "git engine not found / git 엔진을 찾을 수 없습니다."}
	if exists():
		return {"ok": true, "message": "workspace mounted"}

	# Teammates' history, built in the bot clone.
	DirAccess.make_dir_recursive_absolute(bot)
	_copy_dir(_content_root().path_join("base"), bot)
	DirAccess.rename_absolute(bot.path_join("gitignore.txt"), bot.path_join(".gitignore"))
	var steps: Array = [
		["init", "-b", "main"],
		["add", ".gitignore", "README.md", "package.json", "src/auth", "src/orders", "src/payments", "tests/orders.test.ts"],
		_as("daniel", ["commit", "-m", "chore: commerce-api skeleton"]),
		["add", "src/users"],
		_as("sophie", ["commit", "-m", "feat(users): show display name on profile"]),
		["add", "src/payments/payments.ts"],
		_as("daniel", ["commit", "--allow-empty", "-m", "chore(payments): refund rules"]),
	]
	for s in steps:
		if _git_sync(bot, s) != 0:
			return {"ok": false, "message": "git %s failed" % " ".join(PackedStringArray(s))}

	DirAccess.make_dir_recursive_absolute(origin)
	OS.execute("git", ["init", "--bare", "-b", "main", origin])
	OS.execute("git", ["-C", origin, "config", "receive.advertisePushOptions", "true"])
	var hooks := origin.path_join("hooks")
	var f := FileAccess.open(hooks.path_join("pre-receive"), FileAccess.WRITE)
	f.store_string(PROTECT_MAIN_HOOK)
	f.close()
	OS.execute("git", ["-C", origin, "config", "core.hooksPath", hooks])
	_git_sync(bot, ["remote", "add", "origin", V_ORIGIN])
	_git_sync(bot, ["push", "-o", BOT_OPTION, "-u", "origin", "main"])

	DirAccess.make_dir_recursive_absolute(home)
	if OS.execute("git", ["-C", home, "clone", V_ORIGIN, "commerce-api"]) != 0:
		return {"ok": false, "message": "clone failed"}
	DirAccess.make_dir_recursive_absolute(ci.get_base_dir())
	OS.execute("git", ["-C", ci.get_base_dir(), "clone", V_ORIGIN, "commerce-api"])
	return {"ok": true, "message": "workspace created"}


func _write_gitconfig() -> void:
	DirAccess.make_dir_recursive_absolute(root)
	var f := FileAccess.open(gitconfig, FileAccess.WRITE)
	f.store_string("""[init]
	defaultBranch = main
[core]
	autocrlf = false
	quotePath = false
	fsmonitor = false
[gc]
	auto = 0
	autoDetach = false
[maintenance]
	auto = false
[receive]
	autogc = false
[credential]
	helper =
[commit]
	gpgsign = false
[tag]
	gpgsign = false
[advice]
	detachedHead = false
	skippedCherryPicks = false
[pull]
	rebase = false
[push]
	autoSetupRemote = true
[url "%s"]
	insteadOf = %s
[safe]
	directory = *
""" % [origin, V_ORIGIN])
	f.close()


const PEOPLE := {
	"daniel": ["Daniel Park", "daniel@nexora.dev"],
	"sophie": ["Sophie Lee", "sophie@nexora.dev"],
	"mina": ["Mina Choi", "mina@nexora.dev"],
	"alex": ["Alex Kim", "alex@nexora.dev"],
	"bot": ["CodeHub", "codehub@nexora.dev"],
}


static func _as(who: String, args: Array) -> Array:
	var p: Array = PEOPLE[who]
	return ["-c", "user.name=" + p[0], "-c", "user.email=" + p[1]] + args


func _git_sync(dir: String, args: Array) -> int:
	var out := []
	return OS.execute("git", PackedStringArray(["-C", dir] + args), out, true)


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for file in DirAccess.get_files_at(from):
		var bytes := FileAccess.get_file_as_bytes(from.path_join(file))
		var f := FileAccess.open(to.path_join(file), FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	for dir in DirAccess.get_directories_at(from):
		_copy_dir(from.path_join(dir), to.path_join(dir))


## Deletes the whole sandbox (new game).
func wipe() -> void:
	_remove_dir(root)
	is_ready = false


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		var p := path.path_join(f)
		FileAccess.set_read_only_attribute(p, false)
		DirAccess.remove_absolute(p)
	for d in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(d))
	DirAccess.remove_absolute(path)


# --- Processes ----------------------------------------------------------------

func run(path: String, args: Array, timeout_sec := 15.0) -> Dictionary:
	active_jobs += 1
	var job := ProcJob.new()
	var result: Dictionary = await job.run(path, PackedStringArray(args), timeout_sec)
	active_jobs -= 1
	return result


func _git_in(dir: String, args: Array, timeout_sec := 20.0) -> Dictionary:
	return await run("git", ["-C", dir] + args, timeout_sec)


## Checks a player git command. Returns "" if allowed, else the reason (shown in the terminal).
func check_git_args(args: Array) -> String:
	if args.is_empty():
		return ""
	var sub := String(args[0])
	if sub in ["--version", "--help"]:
		return ""
	if sub.begins_with("-"):
		return Game.L("git 전역 옵션은 이 터미널에서 지원하지 않습니다.", "Global git options are not supported in this terminal.")
	if sub not in GIT_ALLOWED:
		return Game.L("'git %s' 명령은 이 회사 환경에서 사용할 수 없습니다.", "'git %s' is not available in this company environment.") % sub
	if sub == "remote" and args.size() > 1 and String(args[1]) not in ["-v", "--verbose", "show"]:
		return Game.L("원격 저장소 설정은 변경할 수 없습니다.", "You can't change the remote configuration.")
	if sub == "config":
		for a in args.slice(1):
			var k := String(a)
			if not (k.begins_with("user.") or k in ["--list", "-l", "--get", "--local"] or not k.begins_with("-") and args.find(a) > 1):
				return Game.L("git config 는 user.name / user.email 만 바꿀 수 있습니다.", "git config can only change user.name / user.email.")
	for a in args:
		var s := String(a)
		var opt := s.get_slice("=", 0)
		if opt in GIT_BLOCKED_OPTS:
			return Game.L("옵션 %s 은(는) 사용할 수 없습니다.", "Option %s is not allowed.") % opt
		if opt in GIT_INTERACTIVE and sub in ["add", "rebase", "commit", "checkout", "restore", "reset", "stash", "clean", "merge"]:
			return Game.L("대화형 모드(%s)는 지원하지 않습니다. 파일 단위로 add 하거나 -m 을 사용하세요.", "Interactive mode (%s) is not supported. Add whole files or use -m.") % opt
		if (s.length() > 2 and s[1] == ":" and (s[2] == "/" or s[2] == "\\")) or s.begins_with("\\\\"):
			return Game.L("회사 저장소 밖의 경로는 사용할 수 없습니다.", "Paths outside the company repository are not allowed.")
		if s.begins_with("/") and not s.begins_with(V_REPO):
			return Game.L("회사 저장소 밖의 경로는 사용할 수 없습니다.", "Paths outside the company repository are not allowed.")
		if ".." in s.split("/") or ".." in s.split("\\"):
			return Game.L("상위 경로(..)는 사용할 수 없습니다.", "Parent paths (..) are not allowed.")
	return ""


## Runs a real git command in the player's working copy, then checks for game events.
func git(args: Array, literal_paths := false) -> Dictionary:
	if _player_git_busy:
		return {"code": -1, "out": "", "err": Game.L("다른 Git 작업이 끝나면 다시 시도하세요.", "Try again when the other Git operation finishes."), "timed_out": false}
	_player_git_busy = true
	var before := _snap.duplicate(true)
	var result := await _working_git(args, literal_paths)
	await refresh(String(args[0]) if result["code"] == 0 and not args.is_empty() else "", before)
	_player_git_busy = false
	return result


## Used by Pork and AICode to inspect the working copy without reporting a player command.
func _working_git(args: Array, literal_paths := false) -> Dictionary:
	var options := ["--literal-pathspecs"] if literal_paths else []
	var result := await _git_in(repo, options + args, 20.0)
	result["out"] = virtualize(result["out"])
	result["err"] = virtualize(result["err"])
	return result


## Apply checked, game-authored changes with Git's all-or-nothing patch validation.
func apply_agent_patch(patch: String, reverse := false) -> String:
	if _player_git_busy or _player_tests_running > 0:
		return Game.L("현재 Git 작업이나 테스트가 끝난 뒤 다시 시도하세요.", "Try again after the current Git command or test run finishes.")
	var patch_path := root.path_join("aicode-%d.patch" % Time.get_ticks_usec())
	var file := FileAccess.open(patch_path, FileAccess.WRITE)
	if file == null:
		return Game.L("초안 파일을 준비할 수 없습니다.", "The draft file could not be prepared.")
	file.store_string(patch)
	var write_error := file.get_error()
	file.close()
	var output: Array = []
	var args := ["-C", repo, "apply", "--whitespace=nowarn"]
	if reverse:
		args.append("--reverse")
	args.append_array(["--", patch_path])
	var code := OS.execute("git", args, output, true) if write_error == OK else -1
	DirAccess.remove_absolute(patch_path)
	if code == 0:
		repo_changed.emit()
		return ""
	var error := virtualize(String(output[0]).strip_edges()) if not output.is_empty() else ""
	return error if error != "" else Game.L("Git에서 변경 내용을 적용하지 못했습니다.", "Git could not apply the draft.")


func has_node_runtime() -> bool:
	if _node_ok == -1:
		_node_ok = 1 if OS.execute("node", ["--version"]) == 0 else 0
	return _node_ok == 1


## Runs the tests of a checkout (player repo by default).
## Result: { ok, passed, failed, tests: [{name, ok, detail}], output, timed_out, error }
func run_tests(dir := "", emit := true) -> Dictionary:
	if dir == "":
		dir = repo
	if not has_node_runtime():
		return {"ok": false, "passed": 0, "failed": 0, "tests": [], "output": "",
			"error": Game.L("테스트 런타임(Node.js)을 찾을 수 없습니다.", "Test runtime (Node.js) not found.")}
	var files: Array = []
	var tests_dir := dir.path_join("tests")
	if DirAccess.dir_exists_absolute(tests_dir):
		for f in DirAccess.get_files_at(tests_dir):
			if f.ends_with(".test.ts"):
				files.append(tests_dir.path_join(f))
	if files.is_empty():
		return {"ok": false, "passed": 0, "failed": 0, "tests": [], "output": "", "error": Game.L("테스트 파일이 없습니다.", "No test files.")}
	if dir == repo:
		_player_tests_running += 1
	var r := await run("node", ["--experimental-strip-types", "--no-warnings", "--test",
		"--test-reporter=tap", "--test-timeout=8000"] + files, 25.0)
	if dir == repo:
		_player_tests_running -= 1
	var parsed := _parse_tap(r["out"])
	parsed["timed_out"] = r["timed_out"]
	parsed["output"] = virtualize(r["out"] + r["err"])
	parsed["ok"] = not r["timed_out"] and parsed["failed"] == 0 and parsed["passed"] > 0
	if r["timed_out"]:
		parsed["error"] = Game.L("테스트가 25초 안에 끝나지 않아 중단했습니다. (무한 루프?)", "Tests did not finish within 25 seconds and were stopped. (Infinite loop?)")
	for t in parsed["tests"]:
		t["detail"] = (t["detail"] as Array).map(func(d): return virtualize(d))
	if emit:
		tests_finished.emit(parsed)
	return parsed


static func _parse_tap(out: String) -> Dictionary:
	var tests: Array = []
	var passed := 0
	var failed := 0
	var grab_next := false
	for raw in out.split("
"):
		var line := raw.strip_edges(false, true)
		var s := line.strip_edges()
		if line.begins_with("ok ") or line.begins_with("not ok "):
			var test_name := line.get_slice(" - ", 1) if " - " in line else line
			tests.append({"name": test_name, "ok": line.begins_with("ok "), "detail": []})
			grab_next = false
		elif line.begins_with("# pass "):
			passed = int(line.get_slice(" ", 2))
		elif line.begins_with("# fail "):
			failed = int(line.get_slice(" ", 2))
		elif not tests.is_empty() and not tests[-1]["ok"]:
			var detail: Array = tests[-1]["detail"]
			if grab_next and s != "":
				detail.append(s)
				grab_next = false
			elif s == "error: |-":
				grab_next = true
			elif s.begins_with("expected:") or s.begins_with("actual:") or s.begins_with("error:"):
				detail.append(s)
	return {"passed": passed, "failed": failed, "tests": tests}


# --- Teammates (bot clone) ----------------------------------------------------

func _bot_lock() -> void:
	while _bot_busy:
		await get_tree().process_frame
	_bot_busy = true


## A teammate commits files to a branch on origin (bypassing branch protection).
## files: { "path": "content" or null (delete) }. base: branch to start a new branch from.
func bot_commit(who: String, branch_name: String, files: Dictionary, message: String, base := "main") -> bool:
	await _bot_lock()
	await _git_in(bot, ["fetch", "-q", "origin", "--prune"])
	var exists_remote: bool = (await _git_in(bot, ["rev-parse", "-q", "--verify", "origin/" + branch_name]))["code"] == 0
	await _git_in(bot, ["checkout", "-q", "-f", "-B", branch_name, "origin/" + (branch_name if exists_remote else base)])
	for path in files:
		var p := bot.path_join(path)
		if files[path] == null:
			DirAccess.remove_absolute(p)
		else:
			DirAccess.make_dir_recursive_absolute(p.get_base_dir())
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(files[path])
			f.close()
	await _git_in(bot, ["add", "-A"])
	var c := await _git_in(bot, _as(who, ["commit", "-q", "-m", message]))
	var p2 := await _git_in(bot, ["push", "-q", "-o", BOT_OPTION, "origin", branch_name])
	_bot_busy = false
	if branch_name == "main":
		main_updated.emit()
	return c["code"] == 0 and p2["code"] == 0


func _content_root() -> String:
	return "res://content/commerce-api/" + String(Game.state.get("repo_lang", "ko"))


## A content file (res://) in the language the company repo was created in.
func content(path: String) -> String:
	return FileAccess.get_file_as_string(_content_root().path_join(path))


func ci_content_dir(folder: String) -> String:
	return "res://content/ci/%s/%s" % [String(Game.state.get("repo_lang", "ko")), folder]


## Merges origin/<branch> into origin/main as a merge commit. Returns { ok, conflict, sha }.
func bot_merge(branch_name: String, message: String, who := "bot") -> Dictionary:
	await _bot_lock()
	await _git_in(bot, ["fetch", "-q", "origin", "--prune"])
	await _git_in(bot, ["checkout", "-q", "-f", "-B", "main", "origin/main"])
	var m := await _git_in(bot, _as(who, ["merge", "--no-ff", "-m", message, "origin/" + branch_name]))
	if m["code"] != 0:
		await _git_in(bot, ["merge", "--abort"])
		await _git_in(bot, ["reset", "-q", "--hard", "origin/main"])
		_bot_busy = false
		return {"ok": false, "conflict": true}
	var p := await _git_in(bot, ["push", "-q", "-o", BOT_OPTION, "origin", "main"])
	var sha := String((await _git_in(bot, ["rev-parse", "HEAD"]))["out"]).strip_edges()
	_bot_busy = false
	await refresh()
	main_updated.emit()
	return {"ok": p["code"] == 0, "conflict": false, "sha": sha}


## True if origin/<branch> merges cleanly into origin/main.
func can_merge(branch_name: String) -> bool:
	await _bot_lock()
	await _git_in(bot, ["fetch", "-q", "origin", "--prune"])
	var r := await _git_in(bot, ["merge-tree", "--write-tree", "origin/main", "origin/" + branch_name])
	_bot_busy = false
	return r["code"] == 0


func remote_sha(branch_name: String) -> String:
	var r := await _git_in(origin, ["rev-parse", "-q", "--verify", "refs/heads/" + branch_name])
	return String(r["out"]).strip_edges() if r["code"] == 0 else ""


func remote_branches() -> Array:
	var r := await _git_in(origin, ["for-each-ref", "--format=%(refname:short)", "refs/heads"])
	return Array(String(r["out"]).strip_edges().split("\n", false))


## Diff of a branch against main on origin (three-dot: what the PR introduces).
func pr_diff(branch_name: String) -> String:
	await _bot_lock()
	await _git_in(bot, ["fetch", "-q", "origin", "--prune"])
	var r := await _git_in(bot, ["diff", "origin/main...origin/" + branch_name])
	_bot_busy = false
	return r["out"]


func pr_commits(branch_name: String) -> Array:
	await _bot_lock()
	var r := await _git_in(bot, ["log", "--format=%h|%an|%s", "origin/main..origin/" + branch_name])
	_bot_busy = false
	return Array(String(r["out"]).strip_edges().split("\n", false))


## Checks out a commit in the CI clone, adds hidden tests, runs everything.
func ci_run(sha: String, hidden_tests: Dictionary) -> Dictionary:
	while _ci_busy:
		await get_tree().process_frame
	_ci_busy = true
	await _git_in(ci, ["fetch", "-q", "origin", "--prune"])
	await _git_in(ci, ["checkout", "-q", "-f", "--detach", sha])
	await _git_in(ci, ["clean", "-q", "-fdx"])
	for name in hidden_tests:
		var f := FileAccess.open(ci.path_join("tests").path_join(name), FileAccess.WRITE)
		f.store_string(hidden_tests[name])
		f.close()
	var r := await run_tests(ci, false)
	_ci_busy = false
	return r


# --- Files ------------------------------------------------------------------

## Resolves a path relative to the repo; returns "" if it escapes the repo.
func resolve(rel: String) -> String:
	rel = devirtualize(rel)
	var full := repo.path_join(rel).simplify_path()
	return full if full == repo or full.begins_with(repo + "/") else ""


func read_file(rel: String) -> String:
	var p := resolve(rel)
	return FileAccess.get_file_as_string(p) if p != "" else ""


func write_file(rel: String, text: String) -> bool:
	var p := resolve(rel)
	if p == "":
		return false
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


## All files in the working copy as repo-relative paths (skips .git, node_modules).
func list_files(rel := "") -> Array:
	var result: Array = []
	var dir := repo.path_join(rel) if rel != "" else repo
	for d in DirAccess.get_directories_at(dir):
		if d == ".git" or d == "node_modules":
			continue
		result.append_array(list_files(rel.path_join(d) if rel != "" else d))
	for f in DirAccess.get_files_at(dir):
		result.append(rel.path_join(f) if rel != "" else f)
	return result


# --- Watching Git -----------------------------------------------------------

func _snapshot() -> Dictionary:
	var head := await _git_in(repo, ["symbolic-ref", "--short", "-q", "HEAD"])
	var last := await _git_in(repo, ["log", "-1", "--format=%H %ae"])
	var local := await _git_in(repo, ["for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads"])
	var remote := await _git_in(origin, ["for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads"])
	var last_parts: PackedStringArray = String(last["out"]).strip_edges().split(" ")
	return {
		"branch": String(head["out"]).strip_edges() if head["code"] == 0 else "(detached)",
		"head": last_parts[0] if last_parts.size() > 0 else "",
		"head_author": last_parts[1] if last_parts.size() > 1 else "",
		"branches": _refs(local["out"]),
		"remote": _refs(remote["out"]),
	}


static func _refs(out: String) -> Dictionary:
	var refs := {}
	for line in out.strip_edges().split("\n", false):
		var p := line.split(" ")
		if p.size() == 2:
			refs[p[0]] = p[1]
	return refs


## Value of a git config key in the player's repo ("" if unset).
func git_config(key: String) -> String:
	var r := await _git_in(repo, ["config", "--get", key])
	return String(r["out"]).strip_edges()


func local_branches() -> Array:
	var r := await _git_in(repo, ["for-each-ref", "--format=%(refname:short)", "refs/heads"])
	return Array(String(r["out"]).strip_edges().split("
", false))


func local_main_synced() -> bool:
	var a := String((await _git_in(repo, ["rev-parse", "-q", "--verify", "refs/heads/main"]))["out"]).strip_edges()
	return a != "" and a == await remote_sha("main")


## Compares Git state with the last snapshot and emits game events.
func refresh(command := "", baseline: Dictionary = {}) -> void:
	if not is_ready:
		return
	var s := await _snapshot()
	var prev := _snap if baseline.is_empty() else baseline
	_snap = s
	branch = s["branch"]
	for b in s["branches"]:
		if not prev["branches"].has(b):
			git_event.emit("branch_created", b)
	if s["branch"] != prev["branch"]:
		git_event.emit("switched", s["branch"])
	if command in ["commit", "merge", "rebase", "cherry-pick", "revert"] and s["head"] != prev["head"] and s["head_author"] != "" and s["head_author"] not in NPC_EMAILS and not _seen_commits.has(s["head"]):
		_seen_commits[s["head"]] = true
		git_event.emit("committed", s["branch"])
	for b in s["remote"]:
		if prev["remote"].get(b, "") != s["remote"][b] and s["branches"].get(b, "") == s["remote"][b]:
			git_event.emit("pushed", b)
	if s["branches"].get("main", "") != prev["branches"].get("main", "") \
			and s["branches"].get("main", "") == s["remote"].get("main", "-"):
		git_event.emit("synced", "main")
	repo_changed.emit()
