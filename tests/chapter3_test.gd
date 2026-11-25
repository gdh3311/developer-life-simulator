extends Node
## Chapter 3 + storylines A (offer) and E (LEGACY-17), across two processes with real Git/Node/CI.
## prevent (ko): direct fixes, both storylines followed, coffee chat wins the evening.
## recover (en): AI draft fails CI then fixed, storylines deferred then accepted, rejected Docs drafts.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const DocsApp := preload("res://scripts/apps/docs_app.gd")
var _checks := 0
var _failures := 0
var _stage := "before"
var _profile := "prevent"
var _terminal: Control
var _ide: Control
var _desktop: Control
var _running := false
var _seen := {}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C03_CHECK: ", message, " = ", ok)
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


func active(id: String) -> bool:
	return Story.active != null and Story.active.id == id and Story.status(id) == "active" and Story.active.data().get("_intro_complete", false)


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


func docs_preview(name: String) -> void:
	var docs := DocsApp.new()
	docs.theme = UITheme.build()
	docs.position = Vector2(40, 40)
	docs.size = Vector2(820, 600)
	add_child(docs)
	await get_tree().process_frame
	await get_tree().process_frame
	check(docs.get_combined_minimum_size().x <= 820, "Docs fits the application width")
	await capture(name)
	docs.queue_free()
	await get_tree().process_frame


func _answer_for(key: String) -> String:
	var rec := _profile == "recover"
	var n := int(_seen.get(key, 0))
	match key:
		"arc_offer_invite": return "later" if rec else "accept"
		"arc_offer_invite2": return "accept"
		"arc_offer_want": return "product" if rec else "depth"
		"arc_offer_avoid": return "handwave" if rec else "silo"
		"arc_offer_task": return "extend" if rec else "weekend"
		"arc_l17_offer": return "later" if rec and Game.day() == 8 else "take"
		"arc_l17_contact": return "official" if rec else "polite"
		"c03_wording": return "midnight" if rec else "seller"
		"c03_policy": return ("refund" if rec and n == 0 else "ask")
		"c03_confused": return "blame" if rec else "wording"
	if key.begins_with("arc_evening_"):
		return "offer|coffee"
	return ""


func _process(_delta: float) -> void:
	if not _running:
		return
	for message in Game.state["chat"].duplicate():
		if message["answered"] == "" and not message["choices"].is_empty():
			var key := String(message["key"])
			var answer := _answer_for(key)
			if answer != "":
				_seen[key] = int(_seen.get(key, 0)) + 1
				Game.answer(int(message["id"]), answer)
				return


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if "--stage" in args:
		_stage = args[args.find("--stage") + 1]
	if "--profile" in args:
		_profile = args[args.find("--profile") + 1]
	Game.lang = "en" if _profile == "recover" else "ko"
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.reset_state()
	if _stage == "after":
		check(Game.load_game(), "loaded the day-8 checkpoint")
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	_running = true
	if _stage == "before":
		await day_eight()
	else:
		await days_nine_ten()
	await finish()


func ship(branch: String, title: String, body: String) -> Dictionary:
	await command("git add .")
	await command('git commit -m "%s"' % title)
	await command("git push")
	var opened := await CodeHub.open_pr(branch, title, body)
	check(opened.get("ok", false), "opened PR " + branch)
	return opened.get("pr", {})


func code_task(branch: String, path: String, fixed: String, objective: String, title: String) -> Dictionary:
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync") and FileAccess.file_exists(Workspace.resolve(path)), "teammate's code arrives via pull: " + path)
	await command("git switch -c " + branch)
	await command("npm test")
	check(not Story.active.is_done(objective), "public tests reject the original " + path)
	await edit(path, Workspace.content(fixed))
	await command("npm test")
	check(Story.active.is_done(objective), "fixed " + path + " passes public tests")
	return await ship(branch, title, "Covers the published rules; tests included.")


# --- Stage 1: chapter transition and day 8 ---------------------------------------------

func day_eight() -> void:
	Game.state["player_name"] = "Continuing Developer"
	Game.state["day"] = 7
	Game.state["day_done"] = true
	Game.state["rank"] = 1
	Game.state["money"] = 300000
	Game.state["flags"]["c02_log_policy"] = true
	Game.state["flags"]["offer_stage"] = "interview" if _profile == "recover" else ""
	for chapter in [1, 2]:
		for mission in Story.chapter_missions(chapter):
			Game.state["story"][mission.id] = {"status": "done", "obj": {}, "data": {}}
	Game.state["story"]["c02_05"]["data"]["found_by"] = "me"
	Game._save()
	await command('git config user.name "Continuing Developer"')
	await command("git config user.email continuing@example.invalid")
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Story.can_continue_chapter(), "finished Chapter 2 offers Chapter 3")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter2_continue_" + Game.lang)
	_desktop._continue_chapter()
	if not await wait_until(func() -> bool: return active("c03_01"), "Chapter 3 starts with the scope task"):
		return
	check(Game.day() == 8 and Game.chapter() == 3 and "MON" in Game.date_text(), "chapter three opens on a Monday in month four")
	check(Story.chapter_missions(3).size() == 8, "eight chapter-three tasks are registered")
	_desktop.queue_free()
	await get_tree().process_frame

	# M01 — scope
	var m = Story.active
	var notes: Array = m.submit_form("scope", {"items": ["deadline", "cancel", "label", "coupon"], "criteria": "vague", "deferred": "promise"})
	check(notes.size() == 3 and not m.is_done("scope"), "over-capacity scope, vague criteria and a promised date are sent back")
	check(m.submit_form("scope", {"items": ["deadline", "label"], "criteria": "exact", "deferred": "record"}).size() == 1, "a missing required item is sent back")
	await docs_preview("docs_scope_" + Game.lang)
	check(m.submit_form("scope", {"items": ["deadline", "cancel", "label"], "criteria": "exact", "deferred": "record"}).is_empty(), "a six-day scope with checkable criteria is accepted")

	# M02 — deadline (storyline invitations fire as the clock passes 10:40 and 12:10)
	if not await wait_until(func() -> bool: return active("c03_02"), "deadline task starts"):
		return
	await wait_until(func() -> bool: return Story.arcs.arc("legacy17").status() != "locked" and Story.arcs.arc("offer").status() != "locked", "both storylines made their first offer")
	if _profile == "recover":
		check(Story.arcs.arc("legacy17").status() == "deferred" and Story.arcs.arc("offer").status() == "deferred", "deferred storylines wait for another offer")
	else:
		check(Story.arcs.active_count() == 2, "both storylines are followed")
	var pr := {}
	if _profile == "recover":
		await command("git switch main")
		await command("git pull")
		await command("git switch -c feature/preorder-deadline")
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		check(ai._on_delegate(true), "AICode applies its draft on the working branch")
		ai.queue_free()
		await command("npm test")
		check(Story.active.is_done("deadline"), "AI draft passes the public deadline tests")
		pr = await ship("feature/preorder-deadline", "feat: seller time-zone deadlines", "Converted seller local time to UTC.")
		if pr.is_empty() or not await wait_until(func() -> bool: return pr["ci"]["state"] == "fail", "hidden CI catches the exact-deadline boundary"):
			return
		await edit("src/preorder/deadline.ts", Workspace.content("c03/deadline_fixed.ts"))
		await command("git add .")
		await command('git commit -m "fix: the deadline minute is closed"')
		await command("git push")
	else:
		pr = await code_task("feature/preorder-deadline", "src/preorder/deadline.ts", "c03/deadline_fixed.ts", "deadline", "feat: seller time-zone deadlines")
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", "deadline fix merged"):
		print("C03_PR: ", JSON.stringify(pr))
		return
	check(int(pr["ci"]["hidden"]) >= 1, "deadline PR ran hidden CI")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 8 ends after its two tasks"):
		return
	var paid := Game.money()
	Game.next_day()
	check(Game.day() == 9 and Game.money() > paid, "day 9 opens and day 8 is paid")
	Game._save()


# --- Stage 2: days 9–10 after a restart ------------------------------------------------

func days_nine_ten() -> void:
	check(Game.day() == 9 and not Game.state["day_done"], "restart lands on day 9")
	var ended := [0]
	Story.chapter_finished.connect(func() -> void: ended[0] += 1)
	await Story.resume()
	# M03 — cancel
	if not await wait_until(func() -> bool: return active("c03_03"), "cancel task starts on day 9"):
		return
	await wait_until(func() -> bool: return Story.active.is_done("policy"), "the blank policy is resolved by asking, not guessing")
	check(Game.state["flags"].get("c03_cancel_policy", false), "the Wiki cancel table is published after asking")
	var pr := await code_task("feature/preorder-cancel", "src/preorder/cancel.ts", "c03/cancel_fixed.ts", "cancelfix", "feat: separate cancel and refund requests")
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", "cancel fix merged"):
		print("C03_PR: ", JSON.stringify(pr))
		return
	# M04 — beta
	if not await wait_until(func() -> bool: return active("c03_04"), "beta task starts"):
		return
	var m = Story.active
	if _profile == "recover":
		check(m.submit_form("beta", {"targets": ["moonlight"], "off": "feel"}).size() == 1, "a feeling-based switch-off rule is sent back")
		check(m.submit_form("beta", {"targets": ["moonlight"], "off": "metric"}).is_empty(), "a narrow beta is allowed")
	else:
		check(m.submit_form("beta", {"targets": ["moonlight", "aurora", "mosaic"], "off": "metric"}).size() == 1, "more than two beta customers is sent back")
		check(m.submit_form("beta", {"targets": ["moonlight", "mosaic"], "off": "metric"}).is_empty(), "a diverse beta is accepted")
	check(Game.state["flags"]["c03_beta_diverse"] == (_profile != "recover"), "beta diversity is recorded for the next task")
	# M05 — labels
	if not await wait_until(func() -> bool: return active("c03_05"), "wording task starts"):
		return
	await wait_until(func() -> bool: return Story.active.is_done("talk"), "answered Mina's finding")
	pr = await code_task("fix/preorder-labels", "src/preorder/labels.ts", "c03/labels_fixed.ts", "labelfix", "fix: ship-by wording")
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", "wording fix merged"):
		return
	# Evening of day 9: storylines compete for the evening.
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 9 ends"):
		return
	var offer = Story.arcs.arc("offer")
	var l17 = Story.arcs.arc("legacy17")
	await wait_until(func() -> bool: return offer.stage() >= 2, "coffee chat with Jamie happened on day 9")
	if _profile == "recover":
		check(not Game.state["flags"].has("arc_evening_9"), "with one evening beat there is no conflict")
		await wait_until(func() -> bool: return l17.form_open("audit"), "the audit sample opens in Docs")
	else:
		check(String(Game.state["flags"].get("arc_evening_9", "")) == "offer|coffee", "two storylines asked for the same evening and the player chose")
		check(l17.data().get("moved", {}).has("audit"), "the unchosen evening moves to tomorrow's lunch")
	Game.next_day()
	Story.start_day(Game.day())
	check(Game.day() == 10, "day 10 opens")
	# Audit form (tonight in recover, at lunch on day 10 in prevent).
	if _profile == "prevent":
		if not await wait_until(func() -> bool: return active("c03_06"), "release task starts"):
			return
		Game.set_time(12 * 60 + 35)
		await wait_until(func() -> bool: return l17.form_open("audit"), "the moved audit beat fires at lunch")
	await docs_preview("docs_audit_" + Game.lang)
	if _profile == "recover":
		check(l17.submit_form("audit", {"rows": ["ORD-2204", "ORD-2207"], "why": "format"}).size() >= 3, "wrong rows and the format hypothesis are explained")
	check(l17.submit_form("audit", {"rows": ["ORD-2204", "ORD-2213", "ORD-2219"], "why": "repay"}).is_empty() and l17.stage() == 2, "the re-payment pattern is found")
	# M06 — release
	if not await wait_until(func() -> bool: return active("c03_06"), "release task is active"):
		return
	m = Story.active
	if _profile == "recover":
		check(m.submit_form("release", {"note": "jargon", "rollback": "none", "checks": ["blocked", "cancel_mix", "cpu"]}).size() == 3, "jargon, no rollback rule and CPU are sent back")
	check(m.submit_form("release", {"note": "plain", "rollback": "metric", "checks": ["blocked", "cancel_mix", "inquiries"]}).is_empty(), "the release is launched")
	# M07 — ownership
	if not await wait_until(func() -> bool: return active("c03_07"), "ownership task starts"):
		return
	m = Story.active
	check(m.submit_form("own", {"owner": "none", "hours": "always", "channel": "dm", "runbook": "later"}).size() == 4, "no owner, anytime, DMs and a later runbook are all sent back")
	check(m.submit_form("own", {"owner": "me" if _profile == "recover" else "pair", "hours": "set", "channel": "shared", "runbook": "now"}).is_empty(), "ownership is set")
	# M08 — review
	if not await wait_until(func() -> bool: return active("c03_08"), "review task starts"):
		return
	m = Story.active
	var options: Array = m.open_forms()[0]["slots"][0]["options"].map(func(o: Dictionary) -> String: return o["id"])
	check("c02_dup" in options and "c02_review" in options and "effort" in options, "review options come from real records")
	check("l17" in options, "storyline work can be brought to the review")
	check(m.submit_form("review", {"records": ["c03_preorder", "effort"], "goal": "depth"}).size() == 1, "effort without evidence is sent back")
	var rank_before := int(Game.state["rank"])
	check(m.submit_form("review", {"records": ["c02_dup", "c03_preorder", "l17"], "goal": "product"}).is_empty(), "the review records are accepted")
	var review: Dictionary = Game.state["flags"].get("c03_review", {})
	check(int(Game.state["rank"]) == rank_before + (1 if review.get("promoted", false) else 0), "promotion or growth plan matches the review result")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "the chapter's last day ends"):
		return
	await wait_until(func() -> bool: return offer.stage() == 3 and l17.stage() == 3, "both storylines reach their Chapter 3 end")
	check(ended[0] == 1, "Chapter 3 reports completion once")
	check(Story.chapter_missions(3).all(func(x) -> bool: return Story.status(x.id) == "done"), "all eight chapter-three tasks are done")
	check(Game.state["flags"].get("l17_note", false), "Hana's design note reached the Wiki")
	check(offer.data().get("task", "") == ("extend" if _profile == "recover" else "weekend"), "take-home decision recorded for Chapter 4")
	check(Story.can_continue_chapter(), "Chapter 4 is offered after Chapter 3")
	var rewards: Dictionary = Game.state["rel"].duplicate(true)
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Game.state["rel"] == rewards, "completed chapter resumes without duplicate rewards")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter3_ending_" + Game.lang)
	var paid := Game.money()
	check(not Game.claim_salary() and Game.money() == paid, "ending cannot duplicate salary")
	_desktop.queue_free()
	Game._save()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER3_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
