extends Node
## CodeHub: the company's Git hosting (pull requests, CI, reviews, merges).
## Branches and merges are real (origin bare repo); PR metadata lives in Game.state.

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


## main moved: re-check whether each open PR still merges cleanly.
func recheck_all() -> void:
	for p in prs():
		if p["state"] != "open":
			continue
		var before: String = p["mergeable"]
		p["mergeable"] = "clean" if await Workspace.can_merge(p["branch"]) else "conflict"
		if p["mergeable"] != before:
			if p["mergeable"] == "conflict":
				_log(p, "system", "main 브랜치가 업데이트되어 충돌이 생겼습니다. main을 작업 브랜치에 병합(git pull origin main)하고 충돌을 해결한 뒤 push 하세요.")
				if p["author"] == ME:
					Game.notify("codehub", "PR #%d" % p["id"], "main과 충돌이 생겼습니다.")
			pr_changed.emit(p["id"])
			Game.emit_event("mergeable", {"pr": p["id"], "conflict": p["mergeable"] == "conflict"})


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "git_pushed":
		for p in open_prs_for(data["branch"]):
			_on_new_commits(p, "새 커밋이 push 되었습니다.")


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
		return {"ok": false, "error": "작업 브랜치를 선택하세요."}
	if not open_prs_for(branch).is_empty():
		return {"ok": false, "error": "이미 열린 PR이 있습니다."}
	if await Workspace.remote_sha(branch) == "":
		return {"ok": false, "error": "원격에 없는 브랜치입니다. 먼저 push 하세요."}
	if title.strip_edges() == "":
		return {"ok": false, "error": "제목을 입력하세요."}
	var pr := _new_pr(ME, branch, title.strip_edges(), body.strip_edges(), "daniel")
	pr["head"] = await Workspace.remote_sha(branch)
	Story.claim_pr(pr)
	_log(pr, "system", "PR을 열었습니다: %s → main" % branch)
	Game.inc_stat("prs")
	Game.advance(5)
	prs_changed.emit()
	Game.emit_event("pr_opened", {"pr": pr["id"]})
	run_ci(pr["id"])
	return {"ok": true, "pr": pr}


## A teammate opens a PR (usually for the player to review).
func npc_pr(author: String, branch: String, title: String, body: String, mission_id: String) -> Dictionary:
	var pr := _new_pr(author, branch, title, body, ME)
	pr["mission"] = mission_id
	pr["head"] = await Workspace.remote_sha(branch)
	_log(pr, author, body)
	prs_changed.emit()
	Game.notify("codehub", "리뷰 요청", "%s 님이 PR #%d 리뷰를 요청했습니다." % [Game.npc_name(author), pr["id"]])
	Game.emit_event("npc_pr_opened", {"pr": pr["id"]})
	run_ci(pr["id"])
	return pr


## Called when a PR branch moved (player push or teammate commit).
func _on_new_commits(pr: Dictionary, note: String) -> void:
	pr["head"] = await Workspace.remote_sha(pr["branch"])
	_log(pr, "system", note)
	if pr["review"]["state"] == "changes":
		pr["review"]["state"] = "pending"
	pr_changed.emit(pr["id"])
	run_ci(pr["id"])


func refresh_pr(id: int, note := "새 커밋이 push 되었습니다.") -> void:
	var pr := get_pr(id)
	if not pr.is_empty():
		await _on_new_commits(pr, note)


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
	_log(pr, "ci", ("CI 통과 · 테스트 %d개" % r["passed"]) if ok else ("CI 실패 · 실패 %d / 통과 %d" % [r["failed"], r["passed"]]))
	if pr["mergeable"] == "conflict":
		_log(pr, "system", "main 브랜치와 충돌이 있습니다. main을 작업 브랜치에 병합(git pull origin main)하고 충돌을 해결한 뒤 push 하세요.")
	Game.inc_stat("ci_pass" if ok else "ci_fail")
	Game.advance(10)
	pr_changed.emit(id)
	if pr["author"] == ME:
		Game.notify("codehub", "PR #%d" % id, "CI %s" % ("통과 ✓" if ok else "실패 ✗ — 실패한 테스트를 확인하세요"))
	Game.emit_event("ci", {"pr": id, "ok": ok, "conflict": pr["mergeable"] == "conflict"})


## Adds a timeline entry. opts: { choices: [{id,label}], key }
func comment(id: int, from: String, text: String, opts := {}) -> void:
	var pr := get_pr(id)
	if pr.is_empty():
		return
	_log(pr, from, text, opts)
	pr_changed.emit(id)
	if from != ME and pr["author"] == ME:
		Game.notify("codehub", "%s · PR #%d" % [Game.npc_name(from), id], text)


func _log(pr: Dictionary, from: String, text: String, opts := {}) -> void:
	pr["timeline"].append({"from": from, "text": text, "time": Game.clock_text().substr(4),
		"choices": opts.get("choices", []), "key": opts.get("key", ""), "answered": ""})
	Game.save_soon()


## A reviewer (teammate) sets the review state: "approved" | "changes" | "commented".
func review(id: int, by: String, state: String, text: String, opts := {}) -> void:
	var pr := get_pr(id)
	if pr.is_empty():
		return
	pr["review"] = {"state": state, "by": by}
	var label: String = {"approved": "✓ 승인", "changes": "변경 요청", "commented": "코멘트"}.get(state, state)
	_log(pr, by, "[%s] %s" % [label, text], opts)
	pr_changed.emit(id)
	Game.advance(20)
	Game.notify("codehub", "%s 님의 리뷰 · PR #%d" % [Game.npc_name(by), id], "%s — %s" % [label, text])
	Game.emit_event("review", {"pr": id, "state": state, "by": by})


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


## Player submits a review on a teammate's PR.
func submit_review(id: int, verdict: String, lines: Array, note: String) -> void:
	var pr := get_pr(id)
	var text := "✓ 승인합니다." if verdict == "approve" else "변경을 요청합니다."
	if not lines.is_empty():
		text += "\n" + "\n".join(lines.map(func(l: Dictionary) -> String: return "  > %s:%d  %s" % [l["file"], l["line"], String(l["text"]).strip_edges()]))
	if note.strip_edges() != "":
		text += "\n" + note.strip_edges()
	_log(pr, ME, text)
	pr["review"] = {"state": "approved" if verdict == "approve" else "changes", "by": ME}
	Game.inc_stat("reviews")
	Game.advance(20)
	pr_changed.emit(id)
	Game.emit_event("player_review", {"pr": id, "verdict": verdict, "lines": lines, "note": note})


## Why the PR can't be merged yet (empty = mergeable).
func merge_blockers(pr: Dictionary) -> Array:
	var reasons: Array = []
	if pr["state"] != "open":
		reasons.append("열린 PR이 아닙니다")
	if pr["ci"]["state"] != "pass":
		reasons.append("CI 통과 필요")
	if pr["review"]["state"] != "approved" and not pr["flags"].get("skip_review", false):
		reasons.append("리뷰 승인 필요")
	if pr["mergeable"] == "conflict":
		reasons.append("충돌 해결 필요")
	return reasons


func merge(id: int, by := ME) -> Dictionary:
	var pr := get_pr(id)
	if pr.is_empty() or not merge_blockers(pr).is_empty():
		return {"ok": false}
	var msg := "Merge pull request #%d from %s\n\n%s" % [id, pr["branch"], pr["title"]]
	var r := await Workspace.bot_merge(pr["branch"], msg, "bot")
	if r.get("conflict", false):
		pr["mergeable"] = "conflict"
		_log(pr, "system", "병합 중 충돌이 발생했습니다. main을 작업 브랜치에 병합해 충돌을 해결하세요.")
		pr_changed.emit(id)
		return {"ok": false, "conflict": true}
	if not r.get("ok", false):
		return {"ok": false}
	pr["state"] = "merged"
	_log(pr, "system", "%s 님이 main에 병합했습니다." % ("내가" if by == ME else Game.npc_name(by)))
	Game.inc_stat("merges")
	Game.advance(5)
	pr_changed.emit(id)
	prs_changed.emit()
	Game.emit_event("pr_merged", {"pr": id, "by": by})
	return {"ok": true}
