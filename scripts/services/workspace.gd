extends Node
## The virtual company's real file system and Git repositories.
##
## - Working copy:  user://VirtualCompany/commerce-api        (the player edits this)
## - "origin":      user://VirtualCompany/remotes/commerce-api.git  (local bare repo)
##
## Git state is real; this service watches it and turns changes into game events.

signal repo_changed
signal git_event(kind: String, detail: String)  # branch_created, switched, committed, pushed
signal tests_finished(result: Dictionary)

const ProcJob := preload("res://scripts/services/proc_job.gd")
const TEMPLATE := "res://content/commerce-api"
const PLAYER_NAME := "New Hire"
const PLAYER_EMAIL := "newhire@nexora.dev"
const PROTECT_MAIN_HOOK := """#!/bin/sh
while read old new ref; do
  if [ "$ref" = "refs/heads/main" ]; then
    echo "main 브랜치는 보호되어 있습니다. 작업 브랜치를 push한 뒤 PR로 병합하세요." >&2
    exit 1
  fi
done
"""

var root := ""
var repo := ""
var origin := ""
var is_ready := false
var branch := "main"
var _snap := {}
var _seen_commits := {}
var _node_ok := -1  # -1 unknown, 0 missing, 1 found


func _ready() -> void:
	# Never let git block on an editor, pager or credential prompt.
	OS.set_environment("GIT_EDITOR", "false")
	OS.set_environment("GIT_PAGER", "cat")
	OS.set_environment("GIT_TERMINAL_PROMPT", "0")
	root = ProjectSettings.globalize_path("user://VirtualCompany")
	repo = root.path_join("commerce-api")
	origin = root.path_join("remotes/commerce-api.git")


# --- Setup ------------------------------------------------------------------

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
	return result


func _prepare_sync() -> Dictionary:
	if OS.execute("git", ["--version"]) != 0:
		return {"ok": false, "message": "git을 찾을 수 없습니다. Git을 설치해 주세요."}
	if DirAccess.dir_exists_absolute(repo.path_join(".git")):
		return {"ok": true, "message": "workspace mounted"}

	DirAccess.make_dir_recursive_absolute(repo)
	_copy_dir(TEMPLATE, repo)
	DirAccess.rename_absolute(repo.path_join("gitignore.txt"), repo.path_join(".gitignore"))

	var steps: Array = [
		["init", "-b", "main"],
		["config", "commit.gpgsign", "false"],
		["config", "core.autocrlf", "false"],
		# Company history, written by teammates.
		["add", ".gitignore", "README.md", "package.json", "src/auth", "src/orders", "src/payments", "tests/orders.test.ts"],
		_as("Daniel Park", "daniel@nexora.dev", ["commit", "-m", "chore: commerce-api skeleton"]),
		["add", "src/users"],
		_as("Sophie Lee", "sophie@nexora.dev", ["commit", "-m", "feat(users): show display name on profile"]),
		["add", "tests/displayName.test.ts"],
		_as("Mina Choi", "mina@nexora.dev", ["commit", "-m", "test(users): reproduce #001 display name bug"]),
	]
	for s in steps:
		if _git_sync(repo, s) != 0:
			return {"ok": false, "message": "저장소 생성 실패: git %s" % " ".join(PackedStringArray(s))}

	DirAccess.make_dir_recursive_absolute(origin)
	if OS.execute("git", ["init", "--bare", "-b", "main", origin]) != 0:
		return {"ok": false, "message": "원격 저장소 생성 실패"}
	_git_sync(repo, ["remote", "add", "origin", origin])
	_git_sync(repo, ["push", "-u", "origin", "main"])

	# Branch protection on the virtual remote.
	var hooks := origin.path_join("hooks")
	var f := FileAccess.open(hooks.path_join("pre-receive"), FileAccess.WRITE)
	f.store_string(PROTECT_MAIN_HOOK)
	f.close()
	OS.execute("git", ["-C", origin, "config", "core.hooksPath", hooks])

	_git_sync(repo, ["config", "user.name", PLAYER_NAME])
	_git_sync(repo, ["config", "user.email", PLAYER_EMAIL])
	return {"ok": true, "message": "workspace created"}


static func _as(who: String, email: String, args: Array) -> Array:
	return ["-c", "user.name=" + who, "-c", "user.email=" + email] + args


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


# --- Processes ----------------------------------------------------------------

func run(path: String, args: Array, timeout_sec := 15.0) -> Dictionary:
	var job := ProcJob.new()
	var result: Dictionary = await job.run(path, PackedStringArray(args), timeout_sec)
	return result


## Runs a real git command in the working copy, then checks for game events.
func git(args: Array) -> Dictionary:
	var result := await run("git", ["-C", repo] + args, 20.0)
	await refresh()
	return result


func has_node_runtime() -> bool:
	if _node_ok == -1:
		_node_ok = 1 if OS.execute("node", ["--version"]) == 0 else 0
	return _node_ok == 1


## Runs the project's tests with Node's built-in test runner.
## Result: { ok, passed, failed, tests: [{name, ok, detail}], output, timed_out, error }
func run_tests() -> Dictionary:
	if not has_node_runtime():
		return {"ok": false, "error": "Node.js 런타임을 찾을 수 없습니다. (출시 버전에서는 게임에 포함됩니다)"}
	var files: Array = []
	for f in DirAccess.get_files_at(repo.path_join("tests")):
		if f.ends_with(".test.ts"):
			files.append(repo.path_join("tests").path_join(f))
	var r := await run("node", ["--experimental-strip-types", "--no-warnings", "--test", "--test-reporter=tap"] + files, 20.0)
	var parsed := _parse_tap(r["out"])
	parsed["timed_out"] = r["timed_out"]
	parsed["output"] = r["out"] + r["err"]
	parsed["ok"] = not r["timed_out"] and parsed["failed"] == 0 and parsed["passed"] > 0
	if r["timed_out"]:
		parsed["error"] = "테스트가 20초 안에 끝나지 않아 중단했습니다. (무한 루프?)"
	tests_finished.emit(parsed)
	return parsed


static func _parse_tap(out: String) -> Dictionary:
	var tests: Array = []
	var passed := 0
	var failed := 0
	for raw in out.split("\n"):
		var line := raw.strip_edges(false, true)
		if line.begins_with("ok ") or line.begins_with("not ok "):
			var ok := line.begins_with("ok ")
			var test_name := line.get_slice(" - ", 1) if " - " in line else line
			tests.append({"name": test_name, "ok": ok, "detail": []})
		elif not tests.is_empty() and not tests[-1]["ok"]:
			var s := line.strip_edges()
			if s.begins_with("expected:") or s.begins_with("actual:"):
				tests[-1]["detail"].append(s)
			elif s.begins_with("error:") and not s.ends_with("|-"):
				tests[-1]["detail"].append(s)
		elif line.begins_with("# pass "):
			passed = int(line.get_slice(" ", 2))
		elif line.begins_with("# fail "):
			failed = int(line.get_slice(" ", 2))
	return {"passed": passed, "failed": failed, "tests": tests}


# --- Files ------------------------------------------------------------------

## Resolves a path relative to the repo; returns "" if it escapes the repo.
func resolve(rel: String) -> String:
	var full := repo.path_join(rel).simplify_path()
	return full if full == repo or full.begins_with(repo + "/") else ""


func read_file(rel: String) -> String:
	var p := resolve(rel)
	return FileAccess.get_file_as_string(p) if p != "" else ""


func write_file(rel: String, text: String) -> bool:
	var p := resolve(rel)
	if p == "":
		return false
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
		var sub := rel.path_join(d) if rel != "" else d
		result.append_array(list_files(sub))
	for f in DirAccess.get_files_at(dir):
		result.append(rel.path_join(f) if rel != "" else f)
	return result


# --- Watching Git -----------------------------------------------------------

func _snapshot() -> Dictionary:
	var head := await run("git", ["-C", repo, "symbolic-ref", "--short", "-q", "HEAD"])
	var last := await run("git", ["-C", repo, "log", "-1", "--format=%H %ae"])
	var local := await run("git", ["-C", repo, "for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads"])
	var remote := await run("git", ["-C", origin, "for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads"])
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


## Compares Git state with the last snapshot and emits game events.
func refresh() -> void:
	if not is_ready:
		return
	var s := await _snapshot()
	var prev := _snap
	_snap = s
	branch = s["branch"]
	for b in s["branches"]:
		if not prev["branches"].has(b):
			git_event.emit("branch_created", b)
	if s["branch"] != prev["branch"]:
		git_event.emit("switched", s["branch"])
	if s["head"] != prev["head"] and s["head_author"] == PLAYER_EMAIL and not _seen_commits.has(s["head"]):
		_seen_commits[s["head"]] = true
		git_event.emit("committed", s["branch"])
	for b in s["remote"]:
		if prev["remote"].get(b, "") != s["remote"][b]:
			git_event.emit("pushed", b)
	repo_changed.emit()
