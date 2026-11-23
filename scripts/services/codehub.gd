extends Node
## CodeHub: the company's Git hosting (pull requests, CI, reviews, merges).
## Branches and merges are real (origin bare repo); PR metadata lives in Game.state.
##
## Permissions: interns/juniors open PRs and leave review comments.
## Only seniors approve and merge (the reviewer merges once CI passes and there is no conflict).

signal pr_changed(id: int)
signal prs_changed

const ME := "me"


func prs() -> Array:
	return Game.state["codehub"]["prs"]


func get_pr(id: int) -> Dictionary:
	for p in prs():
		if int(p["id"]) == id:
			return p
	return {}


func open_prs_for(branch: String) -> Array:
	return prs().filter(func(p: Dictionary) -> bool: return p["branch"] == branch and p["state"] == "open")


func _ready() -> void:
	Game.event.connect(_on_event)
	Workspace.main_updated.connect(recheck_all)


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "git_pushed":
		for p in open_prs_for(data["branch"]):
			_on_new_commits(p, Game.LL("새 커밋이 push 되었습니다.", "New commits were pushed."))


## main moved: re-check whether each open PR still merges cleanly.
func recheck_all() -> void:
	for p in prs():
		if p["state"] != "open":
			continue
		var before: String = p["mergeable"]
		p["mergeable"] = "clean" if await Workspace.can_merge(p["branch"]) else "conflict"
		if p["mergeable"] != before:
			if p["mergeable"] == "conflict":
				_log(p, "system", Game.LL("main 브랜치가 업데이트되어 충돌이 생겼습니다. main을 작업 브랜치에 병합(git pull origin main)하고 충돌을 해결한 뒤 push 하세요.",
					"main was updated and now conflicts. Merge main into your branch (git pull origin main), resolve the conflict and push."))
				if p["author"] == ME:
					Game.notify("codehub", "PR #%d" % p["id"], Game.L("main과 충돌이 생겼습니다.", "Conflicts with main."))
			pr_changed.emit(p["id"])
			Game.emit_event("mergeable", {"pr": p["id"], "conflict": p["mergeable"] == "conflict"})
			_try_auto_merge(p)


## Branches the player can open a PR from (pushed, not main, no open PR).
func pr_candidates() -> Array:
	var result: Array = []
	for b in await Workspace.remote_branches():
		if b != "main" and open_prs_for(b).is_empty():
			result.append(b)
	return result


func _new_pr(author: String, branch: String, title: String, body: String, reviewer: String) -> Dictionary:
	var hub: Dictionary = Game.state["codehub"]
	var pr := {
		"id": int(hub["next_id"]), "title": title, "body": body, "author": author, "branch": branch,
		"state": "open", "head": "", "reviewer": reviewer, "mission": "",
		"ci": {"state": "none", "passed": 0, "failed": 0, "failures": [], "error": ""},
		"review": {"state": "pending", "by": reviewer},
		"mergeable": "unknown", "timeline": [], "day": Game.day(), "flags": {},
	}
	hub["next_id"] = int(hub["next_id"]) + 1
	prs().append(pr)
	return pr


## Player opens a PR. Returns { ok, error, pr }.
func open_pr(branch: String, title: String, body: String) -> Dictionary:
	if branch == "" or branch == "main":
		return {"ok": false, "error": Game.L("작업 브랜치를 선택하세요.", "Pick a working branch.")}
	if not open_prs_for(branch).is_empty():
		return {"ok": false, "error": Game.L("이미 열린 PR이 있습니다.", "A PR is already open for this branch.")}
	if await Workspace.remote_sha(branch) == "":
		return {"ok": false, "error": Game.L("원격에 없는 브랜치입니다. 먼저 push 하세요.", "That branch isn't on the remote. Push it first.")}
	if title.strip_edges() == "":
		return {"ok": false, "error": Game.L("제목을 입력하세요.", "Enter a title.")}
	var pr := _new_pr(ME, branch, title.strip_edges(), body.strip_edges(), "daniel")
	pr["head"] = await Workspace.remote_sha(branch)
	Story.claim_pr(pr)
	if body.strip_edges() == "":
		pr["flags"]["no_body"] = true
	_log(pr, "system", Game.LL("PR을 열었습니다: %s → main" % branch, "Opened the PR: %s → main" % branch))
	Game.inc_stat("prs")
	Game.advance(5)
	prs_changed.emit()
	Game.emit_event("pr_opened", {"pr": pr["id"]})
	run_ci(pr["id"])
	return {"ok": true, "pr": pr}


## A teammate opens a PR. reviewer: who must approve (a senior); the player may comment.
func npc_pr(author: String, branch: String, title: String, body, mission_id: String, reviewer := "daniel") -> Dictionary:
	var pr := _new_pr(author, branch, title, "", reviewer)
	pr["mission"] = mission_id
	pr["flags"]["needs_my_comment"] = true
	pr["flags"]["hold_merge"] = true
	pr["head"] = await Workspace.remote_sha(branch)
	_log(pr, author, body)
	prs_changed.emit()
	Game.notify("codehub", Game.L("리뷰 코멘트 요청", "Review comments requested"),
		Game.L("%s 님이 PR #%d 에 의견을 요청했습니다.", "%s asked for your comments on PR #%d.") % [Game.npc_name(author), pr["id"]])
	Game.emit_event("npc_pr_opened", {"pr": pr["id"]})
	run_ci(pr["id"])
	return pr


func _on_new_commits(pr: Dictionary, note) -> void:
	pr["head"] = await Workspace.remote_sha(pr["branch"])
	_log(pr, "system", note)
	if pr["review"]["state"] == "changes":
		pr["review"]["state"] = "pending"
	pr_changed.emit(pr["id"])
	run_ci(pr["id"])


func refresh_pr(id: int, note = null) -> void:
	var pr := get_pr(id)
	if not pr.is_empty():
		await _on_new_commits(pr, note if note != null else Game.LL("새 커밋이 push 되었습니다.", "New commits were pushed."))


func run_ci(id: int) -> void:
	var pr := get_pr(id)
	if pr.is_empty():
		return
	var sha: String = pr["head"]
	pr["ci"] = {"state": "running", "passed": 0, "failed": 0, "failures": [], "error": "", "sha": sha}
	pr_changed.emit(id)
	var hidden := Story.hidden_tests_for(pr)
	var r := await Workspace.ci_run(sha, hidden)
	if pr["head"] != sha:
		return  # a newer push started another run
	var failures: Array = []
	for t in r["tests"]:
		if not t["ok"]:
			failures.append({"name": t["name"], "detail": t["detail"]})
	var ok: bool = r.get("ok", false)
	pr["ci"] = {"state": "pass" if ok else "fail", "passed": r["passed"], "failed": r["failed"],
		"failures": failures, "error": r.get("error", ""), "sha": sha, "hidden": hidden.size()}
	pr["mergeable"] = "clean" if await Workspace.can_merge(pr["branch"]) else "conflict"
	_log(pr, "ci", Game.LL("CI 통과 · 테스트 %d개" % r["passed"], "CI passed · %d tests" % r["passed"]) if ok
		else Game.LL("CI 실패 · 실패 %d / 성공 %d" % [r["failed"], r["passed"]], "CI failed · %d failed / %d passed" % [r["failed"], r["passed"]]))
	if pr["mergeable"] == "conflict":
		_log(pr, "system", Game.LL("main 브랜치와 충돌이 있습니다. main을 작업 브랜치에 병합(git pull origin main)하고 충돌을 해결한 뒤 push 하세요.",
			"This branch conflicts with main. Merge main into it (git pull origin main), resolve the conflict and push."))
	Game.inc_stat("ci_pass" if ok else "ci_fail")
	Game.advance(10)
	pr_changed.emit(id)
	if pr["author"] == ME:
		Game.notify("codehub", "PR #%d" % id, Game.L("CI 통과 ✓", "CI passed ✓") if ok else Game.L("CI 실패 ✗ — 실패한 테스트를 확인하세요", "CI failed ✗ — check the failing tests"))
		if not ok:
			# Breaking CI costs credibility, a little every time.
			Game.relate("daniel", {"tech": -1})
	Game.emit_event("ci", {"pr": id, "ok": ok, "conflict": pr["mergeable"] == "conflict"})
	_try_auto_merge(pr)


## Adds a timeline entry. text: String or {ko,en}. opts: { choices: [{id,label}], key }
func comment(id: int, from: String, text, opts := {}) -> void:
	var pr := get_pr(id)
	if pr.is_empty():
		return
	_log(pr, from, text, opts)
	pr_changed.emit(id)
	if from != ME and pr["author"] == ME:
		Game.notify("codehub", "%s · PR #%d" % [Game.npc_name(from), id], Game.tx(text))


func _log(pr: Dictionary, from: String, text, opts := {}) -> void:
	pr["timeline"].append({"from": from, "text": text, "time": Game.time_text(),
		"choices": opts.get("choices", []), "key": opts.get("key", ""), "answered": ""})
	Game.save_soon()


static func _both(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {"ko": str(v), "en": str(v)}


## A senior sets the review state: "approved" | "changes" | "commented".
func review(id: int, by: String, state: String, text, opts := {}) -> void:
	var pr := get_pr(id)
	if pr.is_empty():
		return
	pr["review"] = {"state": state, "by": by}
	var label: Dictionary = {"approved": Game.LL("✓ 승인", "✓ Approved"), "changes": Game.LL("변경 요청", "Changes requested"),
		"commented": Game.LL("코멘트", "Comment")}[state]
	var t := _both(text)
	_log(pr, by, {"ko": "[%s] %s" % [label["ko"], t["ko"]], "en": "[%s] %s" % [label["en"], t["en"]]}, opts)
	pr_changed.emit(id)
	Game.advance(20)
	Game.notify("codehub", Game.L("%s 님의 리뷰 · PR #%d", "Review by %s · PR #%d") % [Game.npc_name(by), id], "%s — %s" % [Game.tx(label), Game.tx(t)])
	Game.emit_event("review", {"pr": id, "state": state, "by": by})
	_try_auto_merge(pr)


## Player answers a choice in the PR conversation.
func answer(id: int, index: int, choice_id: String) -> void:
	var pr := get_pr(id)
	var item: Dictionary = pr["timeline"][index]
	if item["answered"] != "":
		return
	item["answered"] = choice_id
	for c in item["choices"]:
		if c["id"] == choice_id:
			_log(pr, ME, c["label"])
	pr_changed.emit(id)
	Game.advance(5)
	Game.emit_event("choice", {"key": item["key"], "option": choice_id, "pr": id})


## Player leaves review comments on a teammate's PR (juniors can't approve).
## stance: "concern" (points out problems) or "lgtm" (looks fine).
func submit_comments(id: int, stance: String, lines: Array, note: String) -> void:
	var pr := get_pr(id)
	var ko := "문제가 있어 보여요." if stance == "concern" else "LGTM — 문제 없어 보여요."
	var en := "I think there's a problem here." if stance == "concern" else "LGTM — looks fine to me."
	var extra := ""
	if not lines.is_empty():
		extra += "\n" + "\n".join(lines.map(func(l: Dictionary) -> String: return "  > %s:%d  %s" % [l["file"], l["line"], String(l["text"]).strip_edges()]))
	if note.strip_edges() != "":
		extra += "\n" + note.strip_edges()
	_log(pr, ME, {"ko": ko + extra, "en": en + extra})
	pr["flags"]["needs_my_comment"] = false
	Game.inc_stat("reviews")
	Game.advance(20)
	pr_changed.emit(id)
	Game.emit_event("player_review", {"pr": id, "verdict": stance, "lines": lines, "note": note})


## What's still needed before the reviewer merges (empty = ready).
func merge_blockers(pr: Dictionary) -> Array:
	var reasons: Array = []
	if pr["state"] != "open":
		reasons.append(Game.L("열린 PR이 아닙니다", "PR is not open"))
	if pr["ci"]["state"] != "pass":
		reasons.append(Game.L("CI 통과", "CI passing"))
	if pr["review"]["state"] != "approved":
		reasons.append(Game.L("시니어 승인", "senior approval"))
	if pr["mergeable"] == "conflict":
		reasons.append(Game.L("충돌 해결", "conflict resolved"))
	return reasons


## Seniors merge approved, green, conflict-free PRs.
func _try_auto_merge(pr: Dictionary) -> void:
	if pr["state"] != "open" or not merge_blockers(pr).is_empty() or pr["flags"].get("merging", false):
		return
	if pr["flags"].get("hold_merge", false):
		return
	pr["flags"]["merging"] = true
	await get_tree().create_timer(2.0).timeout
	pr["flags"]["merging"] = false
	if not merge_blockers(pr).is_empty():
		return
	await merge(int(pr["id"]), String(pr["review"]["by"]))


func merge(id: int, by: String) -> Dictionary:
	var pr := get_pr(id)
	if pr.is_empty() or not merge_blockers(pr).is_empty():
		return {"ok": false}
	var msg := "Merge pull request #%d from %s\n\n%s" % [id, pr["branch"], pr["title"]]
	var r := await Workspace.bot_merge(pr["branch"], msg, "bot")
	if r.get("conflict", false):
		pr["mergeable"] = "conflict"
		_log(pr, "system", Game.LL("병합 중 충돌이 발생했습니다. main을 작업 브랜치에 병합해 충돌을 해결하세요.",
			"The merge hit a conflict. Merge main into your branch and resolve it."))
		pr_changed.emit(id)
		return {"ok": false, "conflict": true}
	if not r.get("ok", false):
		return {"ok": false}
	pr["state"] = "merged"
	_log(pr, "system", Game.LL("%s 님이 main에 병합했습니다." % Game.npc_name(by), "%s merged this into main." % Game.npc_name(by)))
	Game.inc_stat("merges")
	Game.advance(5)
	pr_changed.emit(id)
	prs_changed.emit()
	if pr["author"] == ME:
		Game.notify("codehub", "PR #%d" % id, Game.L("%s 님이 병합했습니다!", "%s merged it!") % Game.npc_name(by))
	Game.emit_event("pr_merged", {"pr": id, "by": by})
	return {"ok": true}
