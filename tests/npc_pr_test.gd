extends Node
## Teammates' PRs (Story.npc_prs) on the real Git/CI workspace:
##  A — a comment that misses → the author's fix misses and hidden CI catches it; a comment on the
##      faulty line → correct fix, merged, `explained`; the next PR repeats the lesson and arrives
##      correct → LGTM merges it → `independent`.
##  B — LGTM without spotting the mistake → hidden CI fails and the reviewer sends it back; fixing it
##      yourself on the branch → merged, `takeover`, nothing learned; the next PR repeats the mistake;
##      pairing with an explanation fixes it and teaches the lesson.
##  C — flagging a PR that was already right → the author asks which line, then LGTM.
##  The CodeHub footer offers the three answers.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
var _checks := 0
var _failures := 0
var _terminal: Control
var _ide: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("NP_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func wait_until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok := bool(predicate.call())
	check(ok, label)
	return ok


func command(line: String) -> void:
	await _terminal._execute(_terminal.tokenize(line))


func edit(path: String, content: String) -> void:
	_ide.open_file(path)
	_ide._code.text = content
	_ide.save()
	await get_tree().create_timer(0.1, true, false, true).timeout


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.reset_state()
	Game.lang = "ko"
	Game.state["day"] = 19
	Game.state["player_name"] = "Review Tester"
	Story.evidence = Story.Evidence.new()
	Story.npc_prs = Story.NpcPrs.new()
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	await command('git config user.name "Review Tester"')
	await command("git config user.email review@example.invalid")
	await _path_a()
	await _path_b()
	await _path_c()
	await finish()


func np():
	return Story.npc_prs


func rec(spec: String) -> Dictionary:
	return np().record(spec)


func line_of(pr: Dictionary, needle: String) -> Dictionary:
	return {"file": "src/shipping/x.ts", "line": 4, "text": needle}


func _ci_done(pr: Dictionary) -> bool:
	return pr["ci"]["state"] in ["pass", "fail"]


## Clears teammate-PR memory and evidence between paths (the Git history stays).
func _forget() -> void:
	Game.state["npc_prs"] = {"prs": {}, "lessons": {}}
	Game.state.erase("evidence")
	Story.evidence = Story.Evidence.new()


func _path_a() -> void:
	var pr: Dictionary = await np().open("jw_shipping")
	check(not pr.is_empty() and pr["author"] == "jiwoo" and NpcPrsSpec(pr) == "jw_shipping", "Jiwoo opens her shipping fee PR")
	check(Game.state["rel"].has("jiwoo"), "Jiwoo gets trust scores when she first appears")
	if not await wait_until(func() -> bool: return _ci_done(pr), "the PR's first CI finishes"):
		return
	check(pr["ci"]["state"] == "pass" and int(pr["ci"].get("hidden", 0)) == 0, "her own tests pass; hidden checks wait for an answer")
	check(pr["flags"].get("needs_my_comment", false), "the PR asks for the player's answer")
	# A comment that doesn't point at the faulty line.
	CodeHub.submit_comments(int(pr["id"]), "concern", [line_of(pr, "  return 3000 + extra * 500;")], "여기 확인해 주세요")
	check(rec("jw_shipping")["mode"] == "comment" and rec("jw_shipping")["pending_fix"] == "wrong", "a comment that misses schedules a fix that misses")
	if not await wait_until(func() -> bool: return pr["ci"]["state"] == "fail" and int(pr["ci"].get("hidden", 0)) == 1, "hidden CI catches the off-target fix"):
		return
	await wait_until(func() -> bool: return pr["flags"].get("needs_my_comment", false), "Jiwoo comes back asking where to look")
	check(pr["timeline"].any(func(e: Dictionary) -> bool: return e["from"] == "jiwoo" and Game.tx(e["text"]).contains("어디를 다시")), "her question is in the PR")
	# A comment on the faulty line.
	CodeHub.submit_comments(int(pr["id"]), "concern", [line_of(pr, "  const extra = Math.max(0, Math.round(weightKg - 2));")], "정책은 올림이에요. 2.3kg으로 확인해 보세요.")
	check(rec("jw_shipping")["learned"] == true, "pointing at the line counts as explaining")
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "the corrected PR is approved and merged"):
		return
	await wait_until(func() -> bool: return rec("jw_shipping")["status"] == "merged", "the teammate PR is recorded as resolved")
	check(rec("jw_shipping")["grade"] == "explained" and Story.evidence.grade("mentoring_evidence") == "explained", "mentoring is recorded as explained")
	check(Story.evidence.source_text("mentoring_evidence") == "지우의 배송비 PR", "the record names the PR")
	check(np().knows("jiwoo", "partial_units"), "Jiwoo learned the lesson")
	check(Workspace.content("npc/jw_shipping/fee_fixed.ts").contains("Math.ceil"), "the fixed content rounds up")
	# The next PR repeats the lesson: it arrives correct.
	var pr2: Dictionary = await np().open("jw_boxes")
	check(rec("jw_boxes")["clean"] == true, "her next PR already applies what she learned")
	if not await wait_until(func() -> bool: return _ci_done(pr2), "the second PR's CI finishes"):
		return
	await _footer_check(pr2)
	CodeHub.submit_comments(int(pr2["id"]), "lgtm", [], "")
	if not await wait_until(func() -> bool: return pr2["state"] == "merged", "LGTM on correct work merges after the hidden checks"):
		return
	await wait_until(func() -> bool: return rec("jw_boxes")["status"] == "merged", "the second PR is resolved")
	check(int(pr2["ci"].get("hidden", 0)) == 1 and rec("jw_boxes")["grade"] == "independent", "the hidden checks ran and she worked independently")
	check(Story.evidence.grade("mentoring_evidence") == "independent" and Story.evidence.first_grade("mentoring_evidence") == "explained", "mentoring rises to independent, history keeps explained")


func NpcPrsSpec(pr: Dictionary) -> String:
	return Story.NpcPrs.spec_of(pr)


func _path_b() -> void:
	_forget()
	var pr: Dictionary = await np().open("jw_shipping")
	check(rec("jw_shipping")["clean"] == false, "a fresh save: the first PR has the mistake")
	if not await wait_until(func() -> bool: return _ci_done(pr), "B: first CI finishes"):
		return
	CodeHub.submit_comments(int(pr["id"]), "lgtm", [], "")
	if not await wait_until(func() -> bool: return pr["review"]["state"] == "changes", "LGTM on the mistake: the reviewer sends it back after hidden CI"):
		return
	check(rec("jw_shipping")["missed"] == 1 and pr["flags"].get("needs_my_comment", false), "the miss is counted and the PR returns to the player")
	# Fix it yourself on Jiwoo's branch.
	np().takeover_hint(int(pr["id"]))
	check(pr["timeline"].any(func(e: Dictionary) -> bool: return e["from"] == "system" and Game.tx(e["text"]).contains("git switch jiwoo/shipping-weight")), "the takeover hint shows the commands")
	await command("git fetch")
	await command("git switch jiwoo/shipping-weight")
	check(Workspace.branch == "jiwoo/shipping-weight", "switched to Jiwoo's branch")
	await command("git pull")
	await edit("src/shipping/fee.ts", Workspace.content("npc/jw_shipping/fee_fixed.ts"))
	await command("npm test")
	await command("git add .")
	await command('git commit -m "fix: round partial kg up"')
	await command("git push")
	check(rec("jw_shipping")["mode"] == "takeover", "pushing to her branch is a takeover")
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "B: the taken-over PR merges"):
		return
	await wait_until(func() -> bool: return rec("jw_shipping")["status"] == "merged", "B: resolved")
	check(rec("jw_shipping")["grade"] == "takeover" and Story.evidence.grade("mentoring_evidence") == "takeover", "mentoring is recorded as takeover")
	check(not np().knows("jiwoo", "partial_units"), "Jiwoo didn't learn it")
	await command("git switch main")
	# The next PR repeats the mistake. Pair and explain.
	var pr2: Dictionary = await np().open("jw_boxes")
	check(rec("jw_boxes")["clean"] == false, "without the lesson, her next PR makes the same mistake")
	if not await wait_until(func() -> bool: return _ci_done(pr2), "B: second CI finishes"):
		return
	var before := Game.minutes()
	check(np().pair(int(pr2["id"])), "pairing starts")
	check(Game.minutes() - before >= 60, "pairing costs an hour")
	var idx := -1
	for i in pr2["timeline"].size():
		if pr2["timeline"][i]["key"] == "npcpr:jw_boxes":
			idx = i
	check(idx >= 0 and pr2["timeline"][idx]["choices"].size() == 2, "Jiwoo asks during pairing with two ways to answer")
	CodeHub.answer(int(pr2["id"]), idx, "explain")
	if not await wait_until(func() -> bool: return pr2["state"] == "merged", "B: the paired fix merges"):
		return
	await wait_until(func() -> bool: return rec("jw_boxes")["status"] == "merged", "B: second PR resolved")
	check(rec("jw_boxes")["grade"] == "explained" and np().knows("jiwoo", "partial_units"), "explaining while pairing teaches the lesson")
	check(Story.evidence.grade("mentoring_evidence") == "explained" and Story.evidence.first_grade("mentoring_evidence") == "takeover", "mentoring rises from takeover to explained")


func _path_c() -> void:
	_forget()
	Game.state["npc_prs"]["lessons"]["jiwoo"] = {"partial_units": true}
	var pr: Dictionary = await np().open("jw_boxes")
	check(rec("jw_boxes")["clean"] == true, "C: a known lesson gives a correct PR")
	if not await wait_until(func() -> bool: return _ci_done(pr), "C: CI finishes"):
		return
	var trust: int = Game.rel("jiwoo", "agree")
	CodeHub.submit_comments(int(pr["id"]), "concern", [line_of(pr, "  return Math.ceil(items / 6);")], "")
	check(pr["flags"].get("needs_my_comment", false) and Game.rel("jiwoo", "agree") < trust, "flagging correct work costs alignment and the PR stays with you")
	check(pr["timeline"].any(func(e: Dictionary) -> bool: return e["from"] == "jiwoo" and Game.tx(e["text"]).contains("어느 부분")), "Jiwoo asks which part")
	CodeHub.submit_comments(int(pr["id"]), "lgtm", [], "")
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "C: LGTM merges it"):
		return
	await wait_until(func() -> bool: return rec("jw_boxes")["status"] == "merged", "C: resolved")
	check(rec("jw_boxes")["grade"] == "independent", "C: still independent")
	var saved := JSON.stringify(Game.state["npc_prs"])
	check((JSON.parse_string(saved) as Dictionary)["prs"]["jw_boxes"]["grade"] == "independent", "teammate PR records survive a save")


func _footer_check(pr: Dictionary) -> void:
	var hub: Control = preload("res://scripts/apps/codehub_app.gd").new()
	hub.size = Vector2(1000, 700)
	add_child(hub)
	hub._selected = int(pr["id"])
	hub._mode = "pr"
	hub._tab = 1
	hub._render()
	var joined := ""
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var texts: Array = []
		for n in hub.find_children("*", "Button", true, false):
			texts.append((n as Button).text)
		joined = " | ".join(texts)
		if joined.contains("Math.ceil(items / 6)"):
			break
	check(joined.contains("댓글: 문제 있음") and joined.contains("LGTM") and joined.contains("직접 고치기") and joined.contains("함께 고치기"), "CodeHub offers comment, fix-it-myself and pairing")
	check(joined.contains("Math.ceil(items / 6)"), "the diff shows her change")
	await capture("npc_pr_footer")
	hub.queue_free()
	await get_tree().process_frame


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0:
		await get_tree().process_frame
	Sfx.stop_all()
	print("NPC_PR_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	Sfx.stop_all()
	for player in Sfx._players + [Sfx._featured] + Sfx._score_players.values():
		player.stream = null
	# The audio thread drops stopped playbacks on its own schedule; give it real time.
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
