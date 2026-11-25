extends Node
## Chapter 4 + storyline beats across two processes with real Git/Node/CI and the mutation check.
## prevent (ko): direct fixes, both storylines through the evening conflict, honest answers.
## recover (en): AI draft fails CI then fixed, rejected drafts first, the take-home ethics trap.

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


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C04_CHECK: ", message, " = ", ok)
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
	await capture(name)
	docs.queue_free()
	await get_tree().process_frame


func _answer_for(key: String) -> String:
	var rec := _profile == "recover"
	match key:
		"c04_legacy_plan": return "delete" if rec else "retire"
		"arc_offer_submit": return "company" if rec else "public"
		"arc_offer_interview": return "deep"
		"arc_offer_terms": return "role"
		"q_finance": return "bluff" if rec else "owner"
		"q_support": return "owner" if rec else "know"
		"q_platform": return "deflect" if rec else "owner"
	if key.begins_with("arc_evening_"):
		return "offer|interview"
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
		check(Game.load_game(), "loaded the day-11 checkpoint")
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	_running = true
	if _stage == "before":
		await day_eleven()
	else:
		await days_twelve_thirteen()
	await finish()


func ship(branch: String, title: String) -> Dictionary:
	await command("git add .")
	await command('git commit -m "%s"' % title)
	await command("git push")
	var opened := await CodeHub.open_pr(branch, title, "Scope and verification described; tests included.")
	check(opened.get("ok", false), "opened PR " + branch)
	return opened.get("pr", {})


# --- Stage 1: Chapter 3 → 4 and day 11 --------------------------------------------------

func day_eleven() -> void:
	Game.state["player_name"] = "Continuing Developer"
	Game.state["day"] = 10
	Game.state["day_done"] = true
	Game.state["rank"] = 2
	Game.state["money"] = 500000
	for chapter in [1, 2, 3]:
		for mission in Story.chapter_missions(chapter):
			Game.state["story"][mission.id] = {"status": "done", "obj": {}, "data": {}}
	Game.state["arcs"] = {
		"offer": {"status": "active", "stage": 3, "data": {"fired": {"invite": 8, "coffee": 9, "task": 10}}},
		"legacy17": {"status": "active", "stage": 3, "data": {"fired": {"offer": 8, "audit": 9, "former": 10}}},
	}
	Game.state["flags"]["l17_pattern"] = true
	Game.state["flags"]["l17_note"] = true
	Game._save()
	await command('git config user.name "Continuing Developer"')
	await command("git config user.email continuing@example.invalid")
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Story.can_continue_chapter(), "finished Chapter 3 offers Chapter 4")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	_desktop._continue_chapter()
	if not await wait_until(func() -> bool: return active("c04_01"), "Chapter 4 starts with the legacy branch"):
		return
	check(Game.day() == 11 and Game.chapter() == 4 and Story.chapter_missions(4).size() == 8, "Chapter 4 opens on day 11 with eight tasks")
	_desktop.queue_free()
	await get_tree().process_frame

	# M01 — characterization tests proved by deleting the branch.
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync") and "legacy" in Workspace.read_file("src/refunds/refund.ts"), "the refund module arrives via pull")
	await command("git switch -c test/refund-characterization")
	await command("npm test")
	await wait_until(func() -> bool: return Story.active.data().has("mutation"), "the mutation check ran on the starter tests")
	check(not Story.active.is_done("pinned") and Story.active.data()["mutation"]["mutant"], "starter tests don't notice the legacy branch being deleted")
	await edit("tests/refund_characterization.test.ts", Workspace.content("c04/refund_characterization_solution.ts"))
	await command("npm test")
	if not await wait_until(func() -> bool: return Story.active.is_done("pinned"), "tests that fail without the legacy branch pin the behavior"):
		return
	await wait_until(func() -> bool: return Story.active.is_done("plan"), "the legacy branch gets a plan")
	check(Game.state["flags"]["c04_legacy_plan"] == "retire", "deleting it now is talked down into a retirement plan")
	var pr := await ship("test/refund-characterization", "test: pin refund behavior incl. legacy")
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", "characterization tests merged"):
		return

	# M02 — find the author, ask good questions.
	if not await wait_until(func() -> bool: return active("c04_02"), "author task starts"):
		return
	await command("git log -- src/refunds/refund.ts")
	check(Story.active.is_done("found"), "git log finds who wrote it")
	var m = Story.active
	check(m.submit_form("questions", {"q": ["blame", "context", "changed"]}).size() == 1, "a blaming question is sent back")
	await docs_preview("docs_questions_" + Game.lang)
	check(m.submit_form("questions", {"q": ["context", "temporary", "changed"]}).is_empty() and Game.state["flags"].get("c04_background", false), "Daniel explains the 2023 contract")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 11 ends"):
		return
	var offer = Story.arcs.arc("offer")
	if _profile == "recover":
		await wait_until(func() -> bool: return offer.status() == "dropped", "submitting company code ends the Brightloop process")
		check(Game.state["flags"].get("offer_ethics", false), "the ethics slip is remembered")
	else:
		await wait_until(func() -> bool: return offer.stage() == 4, "the take-home is submitted with public knowledge")
	Game.next_day()
	check(Game.day() == 12, "day 12 opens")
	Game._save()


# --- Stage 2: days 12–13 ---------------------------------------------------------------

func days_twelve_thirteen() -> void:
	check(Game.day() == 12 and not Game.state["day_done"], "restart lands on day 12")
	var ended := [0]
	Story.chapter_finished.connect(func() -> void: ended[0] += 1)
	await Story.resume()
	var offer = Story.arcs.arc("offer")
	var l17 = Story.arcs.arc("legacy17")
	# M03 — dual write.
	if not await wait_until(func() -> bool: return active("c04_03"), "dual-write task starts"):
		return
	await command("git switch main")
	await command("git pull")
	await command("git switch -c fix/dual-write")
	await command("npm test")
	check(not Story.active.is_done("dualfix"), "the swallowing draft fails the public tests")
	var pr := {}
	if _profile == "recover":
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		check(ai._on_delegate(true), "AICode applies its draft on the working branch")
		ai.queue_free()
		await command("npm test")
		check(Story.active.is_done("dualfix"), "the AI draft passes the public tests")
		pr = await ship("fix/dual-write", "fix: queue ledger failures")
		if pr.is_empty() or not await wait_until(func() -> bool: return pr["ci"]["state"] == "fail", "hidden CI catches old-store failures and duplicates"):
			return
		await edit("src/atlas/dual_write.ts", Workspace.content("c04/dual_write_fixed.ts"))
		await command("git add .")
		await command('git commit -m "fix: failed old writes and single retries"')
		await command("git push")
	else:
		await edit("src/atlas/dual_write.ts", Workspace.content("c04/dual_write_fixed.ts"))
		await command("npm test")
		check(Story.active.is_done("dualfix"), "the fixed adapter passes the public tests")
		pr = await ship("fix/dual-write", "fix: never lose comparison records")
	if pr.is_empty() or not await wait_until(func() -> bool: return pr["state"] == "merged", "dual-write fix merged"):
		print("C04_PR: ", JSON.stringify(pr))
		return
	# M04 — reconciliation.
	if not await wait_until(func() -> bool: return active("c04_04"), "reconciliation task starts"):
		return
	var m = Story.active
	var right := {"r1": "rounding", "r2": "period", "r3": "unit", "r4": "missing", "r5": "rounding", "r6": "period"}
	if _profile == "recover":
		var wrong := right.duplicate()
		wrong["r4"] = "tolerance"
		wrong["r3"] = "rounding"
		check(m.submit_form("recon", wrong).size() == 2, "hiding a gap as tolerance and a wrong cause are both sent back")
	await docs_preview("docs_recon_" + Game.lang)
	check(m.submit_form("recon", right).is_empty(), "the reconciliation report is accepted")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day 12 ends"):
		return
	if _profile == "prevent":
		await wait_until(func() -> bool: return String(Game.state["flags"].get("arc_evening_12", "")) == "offer|interview", "the interview and the migration rule competed for the evening")
		await wait_until(func() -> bool: return offer.stage() == 5, "the technical interview went well")
	else:
		await wait_until(func() -> bool: return l17.form_open("migration"), "the migration rule opens in Docs")
	Game.next_day()
	Story.start_day(Game.day())
	# M05 — scope decision.
	if not await wait_until(func() -> bool: return active("c04_05"), "scope decision starts on day 13"):
		return
	m = Story.active
	if _profile == "recover":
		check(m.submit_form("decision", {"scope": "rewrite", "rollback": "none", "evidence": ["feeling"]}).size() == 3, "an unstaffed rewrite with no rollback and a feeling is sent back")
	check(m.submit_form("decision", {"scope": "phased", "rollback": "flag", "evidence": ["bench", "recon"]}).is_empty(), "a scope two people can finish is accepted")
	# M06 — pilot.
	if not await wait_until(func() -> bool: return active("c04_06"), "pilot task starts"):
		return
	check(Story.active.submit_form("pilot", {"seller": "mosaic", "bar": "loose"}).size() == 1, "a percentage bar is sent back")
	check(Story.active.submit_form("pilot", {"seller": "mosaic", "bar": "zero"}).is_empty(), "the complex seller is piloted")
	# M07 — review load (the lunch-time migration beat may fire around here in prevent).
	if not await wait_until(func() -> bool: return active("c04_07"), "review-load task starts"):
		return
	check(Game.state["flags"].get("c04_pilot_findings", 0) == 3, "the complex pilot surfaced three differences")
	if l17.form_open("migration"):
		check(l17.submit_form("migration", {"match": "order_ref", "check": "skip"}).size() == 2, "matching by order reference without a sample is sent back")
		check(l17.submit_form("migration", {"match": "history", "check": "sample"}).is_empty() and l17.stage() == 4, "the migration rule is drafted")
	m = Story.active
	check(m.submit_form("rotation", {"fix": ["harder", "small"] if _profile == "recover" else ["train", "slots"]}).is_empty(), "a review rotation is proposed")
	check(Game.state["flags"].get("daniel_tired", false) == (_profile == "recover"), "asking Daniel to try harder leaves a cost")
	# M08 — decision record.
	if not await wait_until(func() -> bool: return active("c04_08"), "decision record task starts"):
		return
	if not await wait_until(func() -> bool: return Game.state["day_done"], "the chapter's last day ends"):
		return
	check(Game.state["flags"].get("c04_approved", false), "the limited pilot is approved")
	check(int(Game.state["flags"].get("c04_honest_answers", 0)) == (1 if _profile == "recover" else 3), "honest answers are counted")
	check(ended[0] == 1, "Chapter 4 reports completion once")
	check(Story.chapter_missions(4).all(func(x) -> bool: return Story.status(x.id) == "done"), "all eight chapter-four tasks are done")
	check(l17.stage() == 4, "LEGACY-17 reached its migration rule")
	if _profile == "prevent":
		await wait_until(func() -> bool: return offer.stage() == 6, "Brightloop terms are discussed")
	check(not Story.can_continue_chapter(), "no empty Chapter 5 is offered")
	Game.next_day()
	check(Game.day() == 13, "cannot advance past the last implemented chapter")
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
	await capture("chapter4_ending_" + Game.lang)
	_desktop.queue_free()
	Game._save()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER4_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
