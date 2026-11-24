extends Node
## Production flow from shortcut to playable release, on a separate save and Git workspace.

const Desktop := preload("res://scripts/desktop/desktop.gd")
const Art := preload("res://scripts/ui/illustrations.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Rules := preload("res://scripts/services/arcade_rules.gd")
const SOLUTION := "DDDRDRUUURRRD"
var _checks := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	_checks += 1
	print("ARCADE_CHECK: ", label, " = ", ok)
	if not ok:
		_failures += 1
		push_error(label)


func capture(name: String) -> void:
	if "--screenshots" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")
		check(get_viewport().get_texture().get_image().save_png(path) == OK, "captured " + name)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func move_path(board: Control, directions: String) -> void:
	for direction in directions:
		board._gui_input(_key({"R": KEY_RIGHT, "D": KEY_DOWN, "U": KEY_UP, "L": KEY_LEFT}[direction]))


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Game.reset_state()
	get_tree().root.content_scale_size = Vector2i(1080, 740)
	get_tree().root.size = Vector2i(1080, 740)
	var desktop := Desktop.new()
	desktop.theme = UITheme.build()
	desktop.size = Vector2(1080, 740)
	add_child(desktop)
	desktop._boot.hide()
	desktop._input(_key(KEY_F3))
	await get_tree().create_timer(0.35, true, false, true).timeout
	var browser = desktop._find_method(desktop._open["browser"], "current_site")
	var app = desktop._find_method(browser, "_select_product")
	var board: Control = app._board
	check(browser._url.text == "https://arcade.test" and app._mode == "sample", "F3 opens the live sample directly")
	check(not ArcadeStudio.has_source(), "sample does not create work files")
	check(board._sprites.size() == Art.ARCADE_ORDER.size() and board._sprites.values().all(func(sprite: Texture2D) -> bool: return sprite is AtlasTexture), "every board object has a generated sprite")
	check(board._sprites["exit_locked"] != board._sprites["exit_open"], "locked and open exits use distinct art")
	await capture("packet_run_sample")
	board._gui_input(_key(KEY_LEFT))
	check(board.moves == 0 and board.status == "wall", "blocked moves cost nothing")
	move_path(board, "RRDRRRD")
	check(board.status == "locked" and Rules.count(board.mask) == 1, "sample exit requires both packets")
	board._gui_input(_key(KEY_R))
	move_path(board, "DDDRD")
	board.undo()
	check(board.moves == 4 and Rules.count(board.mask) == 0, "undo restores both position and inventory")
	board._gui_input(_key(KEY_R))
	check(ArcadeStudio.test_results().is_empty() and not ArcadeStudio.can_release(), "play activity creates no work progress")

	check((await Workspace.prepare())["ok"], "isolated company workspace is mounted")
	desktop.open_resource("tasks", "products")
	var task_board = desktop._find_method(desktop._open["tasks"], "open_product_tab")
	var work = desktop._find_method(task_board, "_take_ticket")
	check(task_board._tabs.current_tab == 2 and work._start.visible, "product ticket is assigned from TaskBoard")
	work._start.pressed.emit()
	var ide = desktop._find_method(desktop._open["ide"], "open_file")
	check(ide._current == ArcadeStudio.SOURCE and "canExit" in ide._code.text, "taking the assignment opens its actual TypeScript in DevIDE")
	check(not Workspace.list_files().has("studio/packet_level.ts"), "studio work does not enter the campaign Git checkout")
	ide._studio_preview.pressed.emit()
	check(desktop.top_window_app() == "tasks", "editor link returns to the engineering ticket")
	await work._run_tests()
	check(not ArcadeStudio.test_results()[0]["ok"] and not ArcadeStudio.test_results()[1]["ok"], "automated tests detect the missing packet and exit bug")
	check(work._review.disabled and work._publish.disabled, "failed tests block review and release")
	check(app._mode == "sample" and app._modes["release"].disabled, "the failed build stays out of the Arcade catalog")
	work._edit.pressed.emit()
	var typed_key := _key(KEY_X)
	typed_key.unicode = "x".unicode_at(0)
	Input.parse_input_event(typed_key)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ide._is_dirty() and ide._studio_preview.disabled, "typing into the source requires saving before returning to TaskBoard")
	var rewritten := ArcadeStudio.read_source().replace("moveLimit: 9", "moveLimit: 16").replace("'#.....'", "'#P....'")
	ide._code.text = rewritten.replace("return true;", "return collected === total;").replace("Packet Run — Beta", "Packet Run 1.0")
	ide._studio_save.pressed.emit()
	ide._studio_preview.pressed.emit()
	await work._run_tests()
	check(ArcadeStudio.can_request_review() and not work._review.disabled, "saved code and reachable layout pass automated tests")
	check(work._publish.disabled and ArcadeStudio.release().is_empty(), "passing tests alone cannot release")
	await work._request_review()
	check(not ArcadeStudio.approval().is_empty() and not work._publish.disabled, "Daniel approves the rebuilt revision")
	var good_source := ArcadeStudio.read_source()
	check(ArcadeStudio.write_source(good_source + "\n// different revision\n") and not ArcadeStudio.can_release(), "a newer draft cannot use approval from an older revision")
	check(ArcadeStudio.write_source(good_source) and ArcadeStudio.can_release(), "the exact reviewed revision is still eligible for release")
	Game._save()
	ArcadeStudio._reset()
	check(Game.load_game() and ArcadeStudio.can_release(), "approval survives save reload before release")
	work._refresh()
	check(work._checks.get_child_count() == 3, "the reviewed test results appear after reload")
	for toast in desktop._toasts.get_children():
		toast.hide()
	await capture("packet_run_work_ticket")
	check(board.moves == 0, "no game was completed before the release step")
	work._publish.pressed.emit()
	check(app._mode == "release" and not ArcadeStudio.release().is_empty(), "approved code ships without requiring gameplay")
	check(Game.state["issues"].any(func(issue: Dictionary) -> bool: return issue["id"] == ArcadeStudio.ISSUE and issue["status"] == "done"), "work item is complete in TaskBoard")
	check(not ArcadeStudio.can_release(), "same revision cannot be published twice")
	work._play.pressed.emit()
	check(desktop.top_window_app() == "browser" and board.level["title"] == "Packet Run 1.0", "separate product page opens the player's released game")
	move_path(board, SOLUTION)
	check(board.status == "cleared" and board.moves == 13, "released output is a genuinely playable game")
	await capture("packet_run_release")
	check(ArcadeStudio.write_source(good_source + "\nexport !!!\n"), "broken edit can be saved and checked in the normal build")
	check(not await ArcadeStudio.run_tests() and not ArcadeStudio.feedback.is_empty(), "syntax errors explain a failed build")
	check(not ArcadeStudio.is_current_build() and not ArcadeStudio.can_release() and not ArcadeStudio.release().is_empty(), "a broken edit leaves the previous release playable")
	Game._save()
	ArcadeStudio._reset()
	check(Game.load_game() and ArcadeStudio.release().get("level", {}).get("title", "") == "Packet Run 1.0", "published game survives a save reload")
	Sfx.stop_all()
	await get_tree().create_timer(0.12, true, false, true).timeout
	print("ARCADE_QA: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
