extends Node
## Covers the Browser through its real workstation window and interactive controls.

const Desktop := preload("res://scripts/desktop/desktop.gd")
const Art := preload("res://scripts/ui/illustrations.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("BROWSER_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "saved " + name)


func find_button(node: Node, label: String) -> Button:
	if node is Button and label in node.text:
		return node
	for child in node.get_children():
		var match_button := find_button(child, label)
		if match_button != null:
			return match_button
	return null


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.reset_state()
	Game.lang = "ko"
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	get_tree().root.size = Vector2i(1000, 700)
	var desktop := Desktop.new()
	desktop.theme = UITheme.build()
	desktop.size = Vector2(1000, 700)
	add_child(desktop)
	desktop._boot.hide()
	desktop.open_app("browser")
	var browser = desktop._find_method(desktop._open["browser"], "current_site")
	await pause(0.35)
	var window = desktop._open["browser"]
	var initial_bounds := Rect2(window.position, window.size)
	var title_centers: Array[float] = []
	for button in window._actions.get_children():
		var glyph: Control = button.get_child(0).get_child(0)
		var center: Vector2 = button.get_global_rect().get_center()
		title_centers.append(center.y)
		check(center.distance_to(glyph.get_global_rect().get_center()) <= 1.0, "title icon is centered in its button")
	check(title_centers.max() - title_centers.min() <= 1.0, "window controls share one baseline")
	check(window.get_global_rect().encloses(window._body.get_global_rect()), "app content is clipped inside window frame")
	window._maximize_button.pressed.emit()
	await pause(0.23)
	check(Rect2(window.position, window.size).is_equal_approx(window._workspace()) and not window._grip.visible, "maximize fills the workspace above the dock")
	desktop.size = Vector2(970, 680)
	await get_tree().process_frame
	check(Rect2(window.position, window.size).is_equal_approx(window._workspace()), "maximized bounds track a resized desktop")
	desktop.size = Vector2(1000, 700)
	await get_tree().process_frame
	window._maximize_button.pressed.emit()
	await pause(0.23)
	check(Rect2(window.position, window.size).is_equal_approx(initial_bounds) and window._grip.visible, "restore returns to the same bounds")
	check(browser._tabs.columns == 1 and not browser._panes.vertical, "wide Relay window shows the bookmark rail")
	var toolbar: HBoxContainer = browser._back.get_parent()
	for control in toolbar.get_children():
		var rect: Rect2 = control.get_global_rect()
		check(absf(rect.size.y - 36.0) <= 1.0 and absf(rect.position.y - toolbar.global_position.y) <= 1.0, "toolbar control shares the 36 px baseline")
	check(browser._url.text == "https://nexora.test" and browser._back.disabled, "portal is the default bookmark")
	check(browser._art != null and browser._art.get_width() > 1000, "original editorial image imports into the Browser")
	check(Art.website("relay") is AtlasTexture, "the browser brand uses the new raster icon")
	check(browser._tabs.get_child_count() == Art.WEB_ORDER.size() - 1, "a dedicated image is available for every site")
	for index in browser._tabs.get_child_count():
		var bookmark_art: TextureRect = browser._tabs.get_child(index).get_child(0)
		check(bookmark_art.texture == Art.website(Art.WEB_ORDER[index + 1]) and bookmark_art.texture is AtlasTexture, "bookmark uses its original site emblem")

	var guide := find_button(browser._body, "첫 출근 안내")
	check(guide != null, "portal home directs a new hire to the first-day guide")
	guide.pressed.emit()
	check(browser._url.text == "https://nexora.test/start", "first-day guide has a stable direct URL")
	await capture("nexora_first_day")
	var product := find_button(browser._body, "Commerce Cloud 둘러보기")
	product.pressed.emit()
	check(browser._url.text == "https://nexora.test/commerce" and find_button(browser._body, "src/orders/orders.ts") != null, "company product page connects to the actual code paths")
	browser._back.pressed.emit()
	check(browser._url.text == "https://nexora.test/start", "history returns to the guide")
	browser._url.text_submitted.emit("nexora.test/customers")
	check(browser._url.text == "https://nexora.test/customers", "the case study opens when typed in the address bar")
	var customer_story := find_button(browser._body, "재전송 사례 읽기")
	customer_story.pressed.emit()
	check(browser._url.text == "https://devdaily.test/retry", "customer page connects to the independent technical article")
	toolbar.get_child(2).pressed.emit()
	check(browser._url.text == "https://nexora.test", "the toolbar home button opens the company portal")

	var bookmark := find_button(browser._tabs, "DevDaily")
	var before: int = Sfx._next
	bookmark.button_down.emit()
	check(Sfx._next == (before + 1) % Sfx._players.size() and Sfx._players[before].stream.resource_path.ends_with("click.wav"), "real menu button is wired to the soft click")
	bookmark.pressed.emit()
	check(browser._url.text == "https://devdaily.test", "bookmark changes the displayed address")
	check(browser._address_mark.texture == Art.website("news"), "address emblem follows the current site")
	await capture("devdaily_ko")
	var article := find_button(browser._body, "기사 읽기")
	article.pressed.emit()
	check(browser._route == "news/retry" and browser._url.text.ends_with("/retry"), "article opens on its own address")
	check(browser._body.get_child_count() >= 9, "article includes the photo and complete story")
	browser._back.pressed.emit()
	check(browser._route == "news" and not browser._forward.disabled, "back returns to the site index")
	browser._forward.pressed.emit()
	check(browser._route == "news/retry", "forward restores the article")
	browser._url.text_submitted.emit("https://example.com")
	check(browser._address_error.visible and browser._route == "news/retry", "unknown addresses stay inside the game world")
	browser._url.text_submitted.emit("streamly.test/git")
	check(browser._clip_playing and not browser.is_slacking() and not browser._address_error.visible, "direct link opens the work clip")
	await pause(0.35)
	check(browser._clip_elapsed > 0.1, "clip clock advances in play")
	browser._clip_toggle.pressed.emit()
	var paused_at: float = browser._clip_elapsed
	await pause(0.16)
	check(is_equal_approx(browser._clip_elapsed, paused_at) and not browser._clip_playing, "pause stops the clock")
	var caption: String = browser._clip_caption.text
	browser._clip_seek.value = 23.0
	check(browser._clip_caption.text != caption and browser._clip_clock.text.begins_with("0:23"), "seeking updates the caption and clock")
	Game.lang = "en"
	desktop.close_all()
	await get_tree().process_frame
	desktop.open_app("browser")
	browser = desktop._find_method(desktop._open["browser"], "current_site")
	await pause(0.30)
	check(find_button(browser, "Go") != null, "English browser opens with localized controls")
	browser._url.text_submitted.emit("streamly.test")
	await get_tree().process_frame
	check(browser._tile_grid.columns == 3, "Streamly shows three equal columns at full width")
	var plays: Array[float] = []
	for card in browser._tile_grid.get_children():
		plays.append(find_button(card, "Play").global_position.y)
	check(plays.max() - plays.min() <= 1.0, "Streamly actions align across the row")
	await capture("streamly_en")
	browser._url.text_submitted.emit("https://streamly.test/rail/")
	check(browser.is_slacking() and "Play" not in browser._clip_toggle.text, "leisure clip plays under existing walk-by rules")
	await capture("streamly_player_en")

	Game.state["money"] = 200000
	browser._url.text_submitted.emit("shoply.test")
	var buy := find_button(browser._body, Game.won(89000))
	buy.pressed.emit()
	buy.pressed.emit()
	check(Game.money() == 111000 and Game.state["owned"].has("keyboard_rgb"), "same purchase button cannot charge twice before refresh")
	await get_tree().process_frame
	check(find_button(browser._body, "Owned") != null, "Shoply shows the new ownership state")
	await capture("shoply_en")
	Game.say("recruiter", "Can we talk next week?", {"channel": "connectly"})
	browser._url.text_submitted.emit("connectly.test")
	check(Game.state["unread"]["connectly"] == 0 and not browser.is_slacking(), "Connectly keeps messages and read state integrated")
	browser._url.text_submitted.emit("nexora.test")
	var coffee := find_button(browser._body, "Take a break")
	var prior_minutes := Game.minutes()
	coffee.pressed.emit()
	check(Game.minutes() == prior_minutes + 15, "portal break still advances time")
	for toast in desktop._toasts.get_children():
		toast.hide()
	window = desktop._open["browser"]
	desktop.open_app("monitor")
	var monitor = desktop._open["monitor"]
	monitor.position = Vector2(342, 171)
	monitor.size = Vector2(550, 360)
	await pause(0.34)
	check(desktop.top_window_app() == "monitor" and monitor._frame_style.border_color != window._frame_style.border_color, "front window has a distinct frame")
	await capture("workstation_windows")
	monitor._actions.get_child(0).pressed.emit()
	await pause(0.24)
	check(desktop.top_window_app() == "browser" and monitor._frame_style.border_color != window._frame_style.border_color, "minimizing restores focus styling to the visible window")
	window.size = Vector2(430, 520)
	browser._url.text_submitted.emit("devdaily.test")
	await pause(0.2)
	var narrow_article := find_button(browser._body, "Read article")
	check(narrow_article.get_global_rect().end.x <= browser.get_global_rect().end.x, "narrow window keeps the article link inside the browser")
	check(browser._url.get_global_rect().end.x <= browser.get_global_rect().end.x, "address bar fits a narrow window")
	check(browser._panes.vertical and browser._tabs.columns == 4, "compact window moves bookmarks above the content")
	check(narrow_article.get_global_rect().end.y <= browser._scroll.get_global_rect().end.y, "compact lead article action stays in the initial view")
	await capture("relay_compact")

	Game.lang = "ko"
	Story.start_new()
	await pause(1.5)
	desktop.open_resource("chat", "dm:alex")
	await pause(0.25)
	var alex_link := find_button(desktop._open["chat"], "첫 출근 안내 열기")
	check(alex_link != null, "Alex's real welcome message contains a working intranet link")
	if alex_link != null:
		alex_link.pressed.emit()
		check(desktop.top_window_app() == "browser" and browser._url.text == "https://nexora.test/start", "TeamChat takes the player directly to onboarding")
	check((await Workspace.prepare())["ok"], "the Git client preview mounts the real repository")
	desktop.open_app("pork")
	var pork = desktop._find_method(desktop._open["pork"], "_new_branch")
	var deadline := Time.get_ticks_msec() + 8000
	while (pork._reading or pork._history.item_count == 0) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(pork._history.item_count > 1, "Pork loads real commits in its desktop window")
	if pork._history.item_count > 1:
		pork._tabs.current_tab = 1
		pork._history.select(1)
		await pork._show_selection(1)
		check("diff --git" in pork._diff.get_parsed_text(), "selecting a commit opens its actual diff")
		desktop._toasts.hide()
		desktop._guide.hide()
		await capture("pork_git")
	desktop.open_resource("browser", "portal/commerce")
	var source := find_button(browser._body, "src/orders/orders.ts")
	source.pressed.emit()
	var editor = desktop._find_method(desktop._open["ide"], "open_file")
	check(desktop.top_window_app() == "ide" and editor._current == "src/orders/orders.ts", "the product page opens the source in DevIDE")

	Sfx.stop_all()
	await pause(0.12)
	print("BROWSER_QA: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
