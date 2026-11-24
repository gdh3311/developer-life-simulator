extends Node
## Studio product #2: Moonlight's pre-order page from TaskBoard ticket to a clickable release in Relay.

const Art := preload("res://scripts/ui/illustrations.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const PageWork := preload("res://scripts/apps/page_work.gd")
const PageView := preload("res://scripts/apps/page_view.gd")
var _checks := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	_checks += 1
	print("STUDIO_CHECK: ", label, " = ", ok)
	if not ok:
		_failures += 1
		push_error(label)


func capture(name: String) -> void:
	if "--screenshots" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "captured " + name)


func pause(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func find(root: Node, script: Script) -> Node:
	for n in root.find_children("*", "", true, false):
		if n.get_script() == script:
			return n
	return null


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Game.reset_state()
	Game.state["player_name"] = "Studio Tester"
	get_tree().root.content_scale_size = Vector2i(1080, 740)
	get_tree().root.size = Vector2i(1080, 740)
	var desktop := Desktop.new()
	desktop.theme = UITheme.build()
	desktop.size = Vector2(1080, 740)
	add_child(desktop)
	desktop._boot.hide()
	check((await Workspace.prepare())["ok"], "isolated company workspace is mounted")

	desktop.open_resource("tasks", "products")
	await pause(0.2)
	var work = find(desktop._open["tasks"], PageWork)
	check(work != null and not work._start.visible and not PageStudio.available(), "the page ticket waits for Chapter 3")
	Game.state["day"] = 8
	PageStudio.changed.emit()
	check(PageStudio.available() and work._start.visible, "in Chapter 3 the ticket can be taken")

	work._start.pressed.emit()
	await pause(0.2)
	var ide = desktop._find_method(desktop._open["ide"], "open_file")
	check(ide._current == PageStudio.SOURCE and "countdownLabel" in ide._code.text, "taking the ticket opens the page TypeScript in DevIDE")
	check(not Workspace.list_files().has("studio/moonlight_page.ts"), "the page draft stays out of the campaign Git checkout")
	check(Game.state["issues"].any(func(i: Dictionary) -> bool: return i["id"] == PageStudio.ISSUE and i["status"] == "progress"), "the ticket appears in progress on TaskBoard")

	check(not await PageStudio.run_tests(), "the starter page fails the automated tests")
	var results := PageStudio.test_results()
	check(results.size() == 4 and results.all(func(r: Dictionary) -> bool: return not r["ok"]), "all four checks explain what's missing")
	check(work._review.disabled and work._publish.disabled, "failing tests block review and release")

	desktop.open_resource("browser", "moonlight")
	await pause(0.2)
	var view = find(desktop._open["browser"], PageView)
	check(view != null and view.build.is_empty(), "moonlight.shop shows nothing before a release")

	ide.open_file(PageStudio.SOURCE)
	ide._code.text = FileAccess.get_file_as_string("res://tests/fixtures/moonlight_page_ko.ts")
	ide._studio_save.pressed.emit()
	check(await PageStudio.run_tests(), "the finished page passes all checks")
	check(PageStudio.can_request_review() and not PageStudio.can_release(), "passing tests alone cannot release")
	await PageStudio.request_review()
	check(not PageStudio.approval().is_empty() and PageStudio.can_release(), "Daniel approves the rebuilt revision")
	var good := PageStudio.read_source()
	check(PageStudio.write_source(good + "\n// newer\n") and not PageStudio.can_release(), "a newer draft can't use an older approval")
	check(PageStudio.write_source(good) and PageStudio.can_release(), "the reviewed revision is eligible again")
	work._publish.pressed.emit()
	check(not PageStudio.release().is_empty() and Game.state["chat"].any(func(m: Dictionary) -> bool: return m["from"] == "yuri" and "우리 가게" in Game.tx(m["text"])), "the page goes live and the customer reacts")
	check(Game.state["issues"].any(func(i: Dictionary) -> bool: return i["id"] == PageStudio.ISSUE and i["status"] == "done"), "the ticket is done")
	check(not PageStudio.can_release(), "the same revision can't be released twice")

	work._open.pressed.emit()
	await pause(0.3)
	view = find(desktop._open["browser"], PageView)
	check(desktop.top_window_app() == "browser" and view != null and not view.build.is_empty(), "the released page opens in Relay")
	check(view._hero_row.get_child(1).texture == Art.product("hero"), "released storefront displays its new hero photograph")
	var product_photo: TextureRect = view._grid.get_child(0).get_child(0).get_child(0)
	check(product_photo.texture == Art.product("tea") and product_photo.texture is AtlasTexture, "product key renders its photographed item")
	check(view.countdown_text() == "2시간 5분 남음", "the countdown uses the player's wording")
	check(view.button_enabled(0) and not view.button_enabled(1), "a sold-out product can't be pre-ordered")
	check(view.reserve(0) and view.cart.size() == 1 and view.stock[0] == 29, "pre-ordering adds to the cart and uses stock")
	for i in 4:
		view.reserve(2)
	check(view.stock[2] == 0 and not view.button_enabled(2) and not view.reserve(2), "the last cookie sells out the product")
	desktop._toasts.hide()
	await capture("moonlight_page_live")
	var window: Control = desktop._open["browser"]
	var wide_size := window.size
	window.size.x = 430.0
	await pause(0.2)
	var first_button: Button = view._buttons[0][0]
	check(view._hero_row.vertical and view._grid.columns < 3, "narrow storefront stacks the hero and reduces the grid columns")
	check(first_button.get_global_rect().end.x <= window.get_global_rect().end.x, "narrow product photos and buttons stay inside the browser")
	window.size = wide_size
	await pause(0.2)
	view.set_minutes(30)
	check(view.countdown_text() == "30분 남음", "under an hour shows minutes")
	view.set_minutes(0)
	check(view.countdown_text() == "마감" and not view.button_enabled(0) and not view.reserve(0), "after the deadline nothing can be pre-ordered")
	await capture("moonlight_page_closed")

	check(PageStudio.write_source(good + "\nexport !!!\n") and not await PageStudio.run_tests(), "a broken edit fails to build")
	check(not PageStudio.feedback.is_empty() and not PageStudio.release().is_empty(), "the error is explained and the live page stays up")
	Game._save()
	PageStudio._reset()
	check(Game.load_game() and not PageStudio.release().is_empty(), "the release survives a save reload")

	Sfx.stop_all()
	await pause(0.12)
	print("STUDIO_QA: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
