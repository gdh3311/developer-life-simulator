extends Node
## Chapter 5 + storyline beats across two processes with real Git/Node/CI and the 20:00 rush.
## prevent (ko): direct fixes, office visit, Moonlight's extra hour, accepts Brightloop and hands off.
## recover (en): rejected drafts first, AI holds draft fails CI then fixed, declines Seojin (next-day
## follow-up), no offer (the Chapter 4 ethics slip), takes over Mina's work.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const DocsApp := preload("res://scripts/apps/docs_app.gd")
const CampaignView := preload("res://scripts/apps/campaign_view.gd")
var _checks := 0
var _failures := 0
var _stage := "before"
var _profile := "prevent"
var _terminal: Control
var _ide: Control
var _desktop: Control
var _running := false


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C05_CHECK: ", message, " = ", ok)
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


func preview(node: Control, name: String) -> void:
	node.theme = UITheme.build()
	node.position = Vector2(40, 40)
	node.size = Vector2(820, 600)
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	await capture(name)
	node.queue_free()
	await get_tree().process_frame


func _answer_for(key: String) -> String:
	var rec := _profile == "recover"
	match key:
		"arc_offer_visit": return "visit"
		"arc_l17_review": return "now" if rec else "after"
		"c05_extend": return "decline" if rec else "accept"
		"c05_recon": return "later" if rec else "refund"
	return ""


func _process(_delta: float) -> void:
	if not _running:
		return
	for message in Game.state["chat"].duplicate():
		if message["answered"] == "" and not message["choices"].is_empty():
			var answer := _answer_for(String(message["key"]))
			if answer != "":
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
		check(Game.load_game(), "loaded the day-15 checkpoint")
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	_running = true
	if _stage == "before":
		await day_fourteen()
	else:
		await days_fifteen_sixteen()
	await finish()


func ship(branch: String, title: String) -> Dictionary:
	await command("git add .")
	await command('git commit -m "%s"' % title)
	await command("git push")
	var opened := await CodeHub.open_pr(branch, title, "Scope and verification described; tests included.")
	check(opened.get("ok", false), "opened PR " + branch)
	return opened.get("pr", {})


func code_task(id: String, branch: String, objective: String, fixed_path: String, fixed_content: String, use_ai := false) -> bool:
	if not await wait_until(func() -> bool: return active(id), id + " starts"):
		return false
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync") and FileAccess.file_exists(Workspace.resolve(fixed_path)), id + ": the module arrives via pull")
	await command("git switch -c " + branch)
	await command("npm test")
	check(not Story.active.is_done(objective), id + ": the draft fails the public tests")
	var pr := {}
	if use_ai:
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		check(ai._on_delegate(true), id + ": AICode applies its draft on the working branch")
		ai.queue_free()
		await command("npm test")
		check(Story.active.is_done(objective), id + ": the AI draft passes the public tests")
		pr = await ship(branch, "fix: AI draft for " + id)
		if pr.is_empty() or not await wait_until(func() -> bool: return pr["ci"]["state"] == "fail", id + ": hidden CI catches what the draft skipped"):
			return false
		await edit(fixed_path, fixed_content)
		await command("npm test")
		await command("git add .")
		await command('git commit -m "fix: cover the cases CI caught"')
		await command("git push")
	else:
		await edit(fixed_path, fixed_content)
		await command("npm test")
		check(Story.active.is_done(objective), id + ": the fix passes the public tests")
		pr = await ship(branch, "fix: " + id)
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", id + ": merged after CI and review"):
		print("C05_PR: ", JSON.stringify(pr))
		return false
	return true


# --- Stage 1: Chapter 4 → 5 and day 14 --------------------------------------------------

func day_fourteen() -> void:
	Game.state["player_name"] = "Continuing Developer"
	Game.state["day"] = 13
	Game.state["day_done"] = true
	Game.state["rank"] = 2
	Game.state["money"] = 700000
	for chapter in [1, 2, 3, 4]:
		for mission in Story.chapter_missions(chapter):
			Game.state["story"][mission.id] = {"status": "done", "obj": {}, "data": {}}
	var rec := _profile == "recover"
	Game.state["arcs"] = {
		"offer": {"status": "dropped" if rec else "active", "stage": 3 if rec else 6, "data": {"fired": {"invite": 8, "coffee": 9, "task": 10, "submit": 11, "interview": 12, "terms": 13}}},
		"legacy17": {"status": "active", "stage": 4, "data": {"fired": {"offer": 8, "audit": 9, "former": 10, "migration": 12}}},
	}
	Game.state["flags"]["c04_approved"] = true
	if rec:
		Game.state["flags"]["offer_ethics"] = true
	else:
		Game.state["flags"]["offer_priority"] = "role"
	Game._save()
	await command('git config user.name "Continuing Developer"')
	await command("git config user.email continuing@example.invalid")
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Story.can_continue_chapter(), "finished Chapter 4 offers Chapter 5")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	_desktop._continue_chapter()
	if not await wait_until(func() -> bool: return active("c05_01"), "Chapter 5 starts with the traffic question"):
		return
	check(Game.day() == 14 and Game.chapter() == 5 and Story.chapter_missions(5).size() == 8, "Chapter 5 opens on day 14 with eight tasks")
	check(Game.npc_role("hana").begins_with("SRE"), "Hana is back as SRE")
	_desktop.queue_free()
	await get_tree().process_frame

	# M01 — read last year's minutes before choosing a scenario.
	var m = Story.active
	check(m.open_forms().is_empty() and m.submit_form("load", {"scenario": "peak", "bottleneck": "inventory"}).size() == 1, "the scenario stays locked until last year's traffic is read")
	var browser := preload("res://scripts/apps/browser_app.gd")
	check(browser.bookmarked({"id": "campaign"}) and not browser.bookmarked({"id": "atlas"}), "the campaign console takes the internal-tool bookmark")
	await preview(CampaignView.new(), "campaign_before_" + Game.lang)
	Game.emit_event("site", {"site": "campaign"})
	check(m.is_done("looked"), "opening campaign.nexora.test counts as reading the traffic")
	if _profile == "recover":
		check(m.submit_form("load", {"scenario": "avg3", "bottleneck": "images"}).size() == 2, "an even 3x average and the wrong bottleneck are sent back")
		check(m.submit_form("load", {"scenario": "max10", "bottleneck": "inventory"}).size() == 1, "10x on every interval is sent back")
	check(m.submit_form("load", {"scenario": "peak", "bottleneck": "inventory"}).is_empty(), "the per-minute scenario with the inventory bottleneck is accepted")

	# M02 — inventory holds (AI draft in recover).
	if not await code_task("c05_02", "fix/last-item", "holdfix", "src/inventory/reserve.ts", Workspace.content("c05/reserve_fixed.ts"), _profile == "recover"):
		return
	# M03 — price cache.
	if not await code_task("c05_03", "fix/price-cache", "pricefix", "src/pricing/price_cache.ts", Workspace.content("c05/price_cache_fixed.ts")):
		return
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 14 ends"):
		return
	var offer = Story.arcs.arc("offer")
	if _profile == "prevent":
		await wait_until(func() -> bool: return String(offer.data().get("visit", "")) == "visit", "the Brightloop office visit happened in the evening")
	else:
		check(offer.status() == "dropped" and not offer.data().has("visit"), "no Brightloop visit after the ethics slip")
	Game.next_day()
	check(Game.day() == 15, "day 15 opens")
	Game._save()


# --- Stage 2: days 15–16 -----------------------------------------------------------------

func days_fifteen_sixteen() -> void:
	check(Game.day() == 15 and not Game.state["day_done"], "restart lands on day 15")
	var ended := [0]
	Story.chapter_finished.connect(func() -> void: ended[0] += 1)
	await Story.resume()
	var l17 = Story.arcs.arc("legacy17")
	var offer = Story.arcs.arc("offer")
	# M04 — webhooks.
	if not await code_task("c05_04", "fix/late-success", "hookfix", "src/payments/webhook.ts", Workspace.content("c05/webhook_fixed.ts")):
		return
	# M05 — on-call rota.
	if not await wait_until(func() -> bool: return active("c05_05"), "rota task starts"):
		return
	var m = Story.active
	if _profile == "recover":
		check(m.submit_form("rota", {"eve": "me", "night": "me", "morning": "me", "rollback": "alex", "scope": "everything"}).size() == 3, "doing every window alone, a PM rollback owner and the whole service are sent back")
		check(m.submit_form("rota", {"eve": "hana", "night": "hana", "morning": "hana", "rollback": "daniel", "scope": "campaign"}).size() == 2, "twelve straight hours and Hana's leave are sent back")
	await preview(DocsApp.new(), "docs_rota_" + Game.lang)
	var rota := {"eve": "me", "night": "hana", "morning": "sophie", "rollback": "daniel", "scope": "campaign"} if _profile == "prevent" \
		else {"eve": "daniel", "night": "me", "morning": "me", "rollback": "hana", "scope": "campaign"}
	check(m.submit_form("rota", rota).is_empty(), "a real rota is accepted")
	check(int(Game.state["flags"].get("c05_rota_self", -1)) == (2 if _profile == "recover" else 1), "my own on-call windows are counted")
	# M06 — staged opening and the rush.
	if not await wait_until(func() -> bool: return active("c05_06"), "opening task starts"):
		return
	m = Story.active
	check(m.submit_form("launch", {"stage": "all", "limit": "off"}).size() == 1, "removing the rate limit is sent back")
	check(m.submit_form("launch", {"stage": "ten", "limit": "keep"}).is_empty(), "the staged opening is accepted")
	if not await wait_until(func() -> bool: return m.is_done("rush"), "20:00 runs through the repository's code"):
		return
	var rush: Dictionary = Game.state["flags"].get("c05_rush", {})
	print("C05_RUSH: ", JSON.stringify(rush).left(500))
	check(int(rush.get("oversold", -1)) == 0 and int(rush.get("duplicateCharges", -1)) == 0 and int(rush.get("wrongPrice", -1)) == 0 and int(rush.get("stuck", -1)) == 0, "the fixed code oversells nothing, charges once, at the right price")
	check((rush.get("reconcile", []) as Array).size() > 0 and int(rush.get("reconcileDuplicates", 1)) == 0, "late successes reach the reconciliation list once each")
	check((rush.get("extra") is Dictionary) == (_profile == "prevent"), "Moonlight's extra hour runs only when granted")
	var view := CampaignView.new()
	add_child(view)
	await get_tree().process_frame
	check(not view.result.is_empty() and not view.result.get("rehearsal", false), "the console shows the real campaign result")
	if _profile == "prevent":
		var reh: Dictionary = await view.rehearse()
		check(int(reh.get("oversold", -1)) == 0 and view.result.get("rehearsal", false) and Game.state["flags"]["c05_rush"] == rush, "a rehearsal reruns the code without overwriting the result")
	view.queue_free()
	await preview(CampaignView.new(), "campaign_after_" + Game.lang)
	Game.emit_event("site", {"site": "campaign"})
	if not await wait_until(func() -> bool: return Story.status("c05_06") == "done", "reading the result closes the launch"):
		return
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 15 ends"):
		return
	check(l17.stage() == 5 and Game.state["flags"].get("l17_reviewed", false), "Hana reviewed the LEGACY-17 rule at lunch")
	Game.next_day()
	Story.start_day(Game.day())
	# M07 — close report.
	if not await wait_until(func() -> bool: return active("c05_07"), "close report starts on day 16"):
		return
	m = Story.active
	if _profile == "recover":
		check(Game.state["chat"].any(func(c: Dictionary) -> bool: return c["from"] == "seojin" and Game.tx(c["text"]).contains("how far ahead")), "Seojin follows up the day after being declined")
	await wait_until(func() -> bool: return m.is_done("recon"), "the reconciliation list is handled")
	if _profile == "recover":
		check(m.submit_form("report", {"include": ["revenue", "praise"]}).size() == 3, "a revenue-only report is sent back")
	check(m.submit_form("report", {"include": ["safety", "recon", "fatigue", "moonlight"]}).is_empty(), "the close report is accepted")
	# M08 — offer and handoff.
	if not await wait_until(func() -> bool: return active("c05_08"), "offer task starts"):
		return
	m = Story.active
	var forms: Array = m.open_forms().map(func(f: Dictionary) -> String: return f["id"])
	if _profile == "prevent":
		check(forms == ["offer"], "the Brightloop offer comes before the handoff")
		check(m.submit_form("offer", {"decision": "accept", "weigh": ["work", "support"]}).is_empty() and Game.state["flags"]["employer"] == "brightloop", "accepting the offer changes employer")
		check(offer.stage() == 7, "the offer storyline reaches its decision")
		await get_tree().create_timer(0.3, true, false, true).timeout
		check(m.submit_form("handoff", {"atlas": "taeseok", "l17": "none"}).size() == 1, "an unowned item is sent back")
		check(m.submit_form("handoff", {"atlas": "taeseok", "l17": "hana"}).is_empty(), "my work is handed off by name")
	else:
		check(forms == ["handoff"], "without an offer only the handoff opens")
		check(m.submit_form("handoff", {"ratelimit": "me", "qa_check": "me"}).is_empty() and Game.state["flags"].get("c05_overload", false), "taking both of Mina's items is accepted with a cost")
		check(Game.state["flags"].get("employer", "") == "nexora", "the employer stays NEXORA")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "the chapter's last day ends"):
		return
	check(ended[0] == 1, "Chapter 5 reports completion once")
	check(Story.chapter_missions(5).all(func(x) -> bool: return Story.status(x.id) == "done"), "all eight chapter-five tasks are done")
	var comments: Dictionary = Game.state["flags"].get("doc_comments", {})
	check(comments.has("c05_05:rota") and comments.has("c05_07:report") and comments.has("c05_08:handoff"), "Chapter 5 documents carry comments in the archive")
	var archived: Array = DocsApp.archive().map(func(d: Dictionary) -> String: return d["key"])
	check("c05_07:report" in archived and "c05_08:handoff" in archived and ("c05_08:offer" in archived) == (_profile == "prevent"), "the report, the handoff and the offer stay re-openable in Docs")
	check(Story.can_continue_chapter(), "Chapter 6 is offered after the handoff")
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done, "the finished chapter resumes into its ending")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter5_ending_" + Game.lang)
	_desktop.queue_free()
	Game._save()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER5_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
