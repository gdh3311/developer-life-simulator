extends Node
## Real editor, agent, Git and CI on both routes, plus lost-order recovery and a saved rehearsal.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const Browser := preload("res://scripts/apps/browser_app.gd")
const Transfer := preload("res://scripts/services/aurora_transfer.gd")

var _checks := 0
var _failures := 0
var _moved := false
var _terminal: Control
var _desktop: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C06_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func wait_for(test: Callable, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while not test.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok := bool(test.call())
	check(ok, message)
	return ok


func active(id: String) -> bool:
	return Story.active != null and Story.active.id == id and Story.status(id) == "active" and Story.active.data().get("_intro_complete", false)


func command(line: String) -> void:
	await _terminal._execute(_terminal.tokenize(line))


func reply(key: String, option: String) -> void:
	for message in Game.state["chat"]:
		if message["key"] == key and message["answered"] == "":
			Game.answer(int(message["id"]), option)
			return
	check(false, "choice available: " + key)


func click(root: Control, title: String) -> bool:
	for button in root.find_children("*", "Button", true, false):
		if button.text == title and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	check(false, "visible button: " + title)
	return false


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	_moved = "recover" in OS.get_cmdline_user_args()
	Game.lang = "en" if _moved else "ko"
	Game.reset_state()
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var result := await Workspace.prepare()
	check(result.get("ok", false), "mounted isolated Git checkout")
	if result.get("ok", false):
		await _play()
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER6_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)


func _play() -> void:
	Game.state["day"] = 16
	Game.state["day_done"] = true
	Game.state["rank"] = 2
	Game.state["flags"]["employer"] = "brightloop" if _moved else "nexora"
	Game.state["flags"]["c05_handoff"] = {"atlas": "hana", "l17": "sophie"} if _moved else {"qa_check": "sophie", "ratelimit": "me"}
	Game._save()
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1280, 720)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(Game.employer_name() == "NEXORA" and Story.can_continue_chapter(), "a completed Chapter 5 save can continue")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	_desktop._continue_chapter()
	if not await wait_for(func() -> bool: return active("c06_01"), "Chapter 6 starts from the real ending"):
		return
	check(Game.employer_name() == ("Brightloop" if _moved else "NEXORA"), "employer comes from the previous decision")
	check(Game.state["chat"].any(func(m: Dictionary) -> bool:
		return String(Game.tx(m["text"])).contains("Hana" if _moved else "Sophie")), "handoff names the actual previous owner")
	check(Browser.bookmarked({"id": "aurora"}) and not Browser.bookmarked({"id": "campaign"}), "Aurora takes the internal bookmark")
	reply("c06_access", "pair" if _moved else "work")
	if not await wait_for(func() -> bool: return active("c06_02"), "the correct team's starter reaches origin"):
		return
	if not await _adapter_pr():
		return
	if not await wait_for(func() -> bool: return active("c06_03"), "reconciliation opens after merge"):
		return
	_desktop.open_resource("browser", "aurora")
	var browser = _desktop._find_method(_desktop._open["browser"], "open_page")
	check(browser.current_site()["id"] == "aurora", "desktop opens the Relay route")
	var selectors: Array = browser.find_children("*", "OptionButton", true, false)
	check(selectors.size() == 2, "both account selectors are displayed")
	if selectors.size() != 2:
		return
	var reconcile := Game.L("두 주문 대조", "Reconcile both orders")
	selectors[0].select(2)
	selectors[1].select(1)
	if not click(browser, reconcile):
		return
	check(active("c06_03"), "swapped sellers fail reconciliation")
	selectors[0].select(1)
	selectors[1].select(2)
	check(click(browser, reconcile) and Story.status("c06_03") == "done", "both orders survive a colliding order number")
	if not await wait_for(func() -> bool: return Game.state["day_done"], "first day closes"):
		return
	Game.next_day()
	Story.start_day(Game.day())
	if not await wait_for(func() -> bool: return active("c06_04"), "second day opens the ownership document"):
		return
	check(Story.active.submit_form("ownership", {"exporter": "brightloop", "importer": "nexora", "stop": "count"}).size() == 3,
		"ownership and seller-level completeness are checked")
	check(Story.active.submit_form("ownership", {"exporter": "nexora", "importer": "brightloop", "stop": "missing"}).is_empty(),
		"both ownership boundaries are accepted")
	if not await wait_for(func() -> bool: return active("c06_05"), "rehearsal opens"):
		return
	check(not Transfer.operate("restore"), "cannot jump straight to rollback")
	var take_order := Game.L("ORD-107 접수", "Receive ORD-107")
	check(click(browser, Game.L("현재 복제본으로 전환", "Switch with the current snapshot")) and
		click(browser, take_order) and click(browser, Game.L("접수 경로만 원복", "Roll back order intake only")), "an unsafe rehearsal can be run and inspected")
	var bad := Transfer.rehearsal()
	check(bad["missing_at_switch"] and bad["missing_at_rollback"] and active("c06_05"), "the report names both losses without completing the mission")
	await capture("aurora_rehearsal_" + Game.lang)
	check(click(browser, Game.L("처음부터 다시 리허설", "Restart the rehearsal")) and
		click(browser, Game.L("변경분 적용 후 전환", "Apply changes, then switch")), "retry reconciles the delta before cutover")
	Game._save()
	check(Game.load_game(), "loaded a save mid-rehearsal")
	await Story.resume()
	check(active("c06_05") and Transfer.rehearsal()["phase"] == "switched", "save preserves the phase and accepted orders")
	check(click(browser, take_order) and click(browser, Game.L("새 주문을 되보낸 뒤 원복", "Copy the new order back, then roll back")),
		"rollback replays the destination's new order")
	check(Transfer.passed(Transfer.rehearsal()), "no orders lost in either direction")
	if not await wait_for(func() -> bool: return active("c06_06"), "partner requests a pilot date"):
		return
	var pilot := "monday" if _moved else "friday"
	reply("c06_handover", pilot)
	if not await wait_for(func() -> bool: return Game.state["day_done"], "Chapter 6 finishes"):
		return
	check(Game.state["flags"]["c06_pilot_window"] == pilot, "both pilot decisions persist")
	check(Story.chapter_missions(6).all(func(m) -> bool: return Story.status(m.id) == "done"), "all six tasks complete")
	check(not Story.can_continue_chapter(), "chapter ends at its recorded handoff")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await capture("chapter6_ending_" + Game.lang)


func _adapter_pr() -> bool:
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	add_child(_terminal)
	_terminal.hide()
	await command('git config user.name "Aurora Developer"')
	await command("git config user.email aurora@example.invalid")
	await command("git pull")
	await command("git switch -c aurora-adapter")
	var name := "import_orders" if _moved else "export_orders"
	var path := "src/transfer/" + name + ".ts"
	check(FileAccess.file_exists(Workspace.resolve(path)), "pulled the correct variant")
	check(not (await Workspace.run_tests()).get("ok", false), "starter fails the public contract")
	var ai := preload("res://scripts/apps/ai_app.gd").new()
	add_child(ai)
	ai.hide()
	check(ai._on_delegate(true), "AICode applies its draft")
	check((await Workspace.run_tests()).get("ok", false), "draft passes the public contract")
	ai.queue_free()
	await command("git add .")
	await command('git commit -m "Draft transfer adapter"')
	await command("git push")
	var opened := await CodeHub.open_pr("aurora-adapter", "Aurora transfer adapter", "Reviewed against the shared contract.")
	check(opened.get("ok", false), "opened a real PR")
	var pr: Dictionary = opened.get("pr", {})
	if pr.is_empty() or not await wait_for(func() -> bool: return pr["ci"]["state"] == "fail", "extra CI rejects the incomplete draft"):
		return false
	check(pr["ci"]["failures"].any(func(f: Dictionary) -> bool: return String(f["name"]).begins_with("[CI]")), "CI identifies the missed contract case")
	var ide := preload("res://scripts/desktop/ide_app.gd").new()
	add_child(ide)
	ide.hide()
	ide.open_file(path)
	var code := Workspace.read_file(path)
	if _moved:
		code = code.replace("rows.set(order.orderId, {\n      accountId: sellerIds[order.sellerCode],",
			"const accountId = sellerIds[order.sellerCode];\n    if (order.version !== 1 || !accountId) continue;\n    rows.set(JSON.stringify([accountId, order.orderId]), {\n      accountId,")
	else:
		code = code.replace("  return {\n", "  const sellerCode = sellerCodes[order.shop];\n  if (!sellerCode) return null;\n  return {\n").replace("sellerCode: sellerCodes[order.shop],", "sellerCode,")
	ide._code.text = code
	ide.save()
	ide.queue_free()
	await command("git add .")
	await command('git commit -m "Handle remaining transfer cases"')
	await command("git push")
	if not await wait_for(func() -> bool: return pr["state"] == "merged", "fixed code passes CI, review, and merge"):
		return false
	check(pr["review"]["by"] == ("raon" if _moved else "daniel"), "reviewer belongs to the route")
	return true


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(8.0).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)
