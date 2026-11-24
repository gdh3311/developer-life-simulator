extends VBoxContainer
## Web browser: the company portal plus sites for slacking off (news, videos, an anonymous
## lounge, shopping) and Connectly, a professional network where recruiters reach out.
## Fun sites restore condition — but a boss walking by might see the screen.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Content := preload("res://scripts/apps/browser_content.gd")
const Arcade := preload("res://scripts/apps/arcade_app.gd")
const ART := "res://content/web/editorial.png"
const PAPER := Color("eeeae1")
const INK := Color("1f2630")
const INK_MUTED := Color("51545c")
const NEWS_ACCENT := Color("984329")
const RELAY := Color("87dcc7")
const SHELL := Color("202a30")
const SHELL_LINE := Color("36484f")
const PAGE_MARGIN := 20
const COMPACT_WIDTH := 680

const SITES := [
	{"id": "portal", "name": "NEXORA", "url": "nexora.test", "fun": false, "color": "5b8cff"},
	{"id": "connectly", "name": "Connectly", "url": "connectly.test", "fun": false, "color": "38bdf8"},
	{"id": "news", "name": "DevDaily", "url": "devdaily.test", "fun": true, "color": "f5a37b"},
	{"id": "video", "name": "Streamly", "url": "streamly.test", "fun": true, "color": "bda1fa"},
	{"id": "lounge", "name": "Lounge", "url": "lounge.test", "fun": true, "color": "a3e635"},
	{"id": "shop", "name": "Shoply", "url": "shoply.test", "fun": true, "color": "7cc5ae"},
	{"id": "arcade", "name": "Arcade", "url": "arcade.test", "fun": false, "color": "f1cd84"},
	{"id": "moonlight", "name": "Moonlight", "url": "moonlight.shop", "fun": false, "color": "f4c95d"},
]

const ITEMS := [
	{"id": "keyboard_rgb", "price": 89000, "name": {"ko": "기계식 RGB 키보드", "en": "Mechanical RGB keyboard"}, "desc": {"ko": "타건감 최고. 책상이 화려해집니다.", "en": "Great feel. Lights up your desk."}},
	{"id": "light_bar", "price": 45000, "name": {"ko": "모니터 라이트바", "en": "Monitor light bar"}, "desc": {"ko": "눈이 덜 피로해요.", "en": "Easier on the eyes."}},
	{"id": "figure", "price": 32000, "name": {"ko": "개발자 로봇 피규어", "en": "Dev robot figure"}, "desc": {"ko": "책상 위 작은 동료.", "en": "A tiny desk buddy."}},
	{"id": "plant_big", "price": 58000, "name": {"ko": "몬스테라 화분", "en": "Monstera plant"}, "desc": {"ko": "공기가 맑아지는 기분.", "en": "Feels fresher already."}},
	{"id": "coffee_machine", "price": 99000, "name": {"ko": "미니 커피머신", "en": "Mini coffee machine"}, "desc": {"ko": "커피 브레이크 효과 2배.", "en": "Coffee breaks restore twice as much."}},
	{"id": "headphones", "price": 150000, "name": {"ko": "노이즈캔슬링 헤드폰", "en": "Noise-cancelling headphones"}, "desc": {"ko": "집중! 컨디션이 덜 떨어집니다.", "en": "Focus! Condition drains slower."}},
	{"id": "neon", "price": 120000, "name": {"ko": "네온사인 </>", "en": "Neon sign </>"}, "desc": {"ko": "벽에 다는 개발자 감성.", "en": "Developer vibes on your wall."}},
]

var desktop: Control
var _site := "portal"
var _route := "portal"
var _history: Array[String] = []
var _history_index := -1
var _url: LineEdit
var _address_error: Label
var _back: Button
var _forward: Button
var _tabs: GridContainer
var _nav: PanelContainer
var _nav_title: Label
var _panes: BoxContainer
var _address_style: StyleBoxFlat
var _address_mark: Control
var _tile_grid: GridContainer
var _lead_photo: TextureRect
var _lead_copy: VBoxContainer
var _lead_title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _surface: PanelContainer
var _timer: Timer
var _art: Texture2D
var _refresh_pending := false
var _clip := {}
var _clip_elapsed := 0.0
var _clip_playing := false
var _clip_toggle: Button
var _clip_seek: HSlider
var _clip_clock: Label
var _clip_caption: Label


func _ready() -> void:
	_art = load(ART)
	set_process(false)
	add_theme_constant_override("separation", 0)
	var chrome := UITheme.panel(SHELL, 0, 0)
	var chrome_style := UITheme.box(SHELL, 0, SHELL_LINE, 0)
	chrome_style.set_border_width_all(0)
	chrome_style.border_width_bottom = 1
	chrome.add_theme_stylebox_override("panel", chrome_style)
	var cv := UITheme.vbox(7)
	var toolbar := UITheme.hbox(8)
	_back = _toolbar_arrow("left", Game.L("뒤로", "Back"))
	_back.pressed.connect(_move_history.bind(-1))
	toolbar.add_child(_back)
	_forward = _toolbar_arrow("right", Game.L("앞으로", "Forward"))
	_forward.pressed.connect(_move_history.bind(1))
	toolbar.add_child(_forward)
	var address := PanelContainer.new()
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_style = UITheme.box(Color("111a20"), 7, SHELL_LINE, 0)
	address.add_theme_stylebox_override("panel", _address_style)
	var address_row := UITheme.hbox(8)
	_address_mark = Icon.make("globe", RELAY, 14)
	_address_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	address_row.add_child(_address_mark)
	_url = LineEdit.new()
	_url.custom_minimum_size = Vector2(132, 36)
	_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_url.select_all_on_focus = true
	_url.placeholder_text = Game.L("게임 속 주소 입력", "Enter an in-game address")
	_url.add_theme_font_size_override("font_size", 13)
	_url.add_theme_font_override("font", UITheme.font(true))
	_url.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_url.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_url.focus_entered.connect(func() -> void: _address_style.border_color = RELAY)
	_url.focus_exited.connect(func() -> void: _address_style.border_color = SHELL_LINE)
	_url.text_submitted.connect(_submit_address)
	address_row.add_child(_url)
	var field := UITheme.margin(address_row, 0)
	field.add_theme_constant_override("margin_left", 11)
	field.add_theme_constant_override("margin_right", 9)
	address.add_child(field)
	toolbar.add_child(address)
	var go := _browser_button(Game.L("이동", "Go"), "", Color("112923"))
	go.custom_minimum_size = Vector2(52, 36)
	go.add_theme_stylebox_override("normal", UITheme.box(RELAY, 7, Color.TRANSPARENT, 7))
	go.add_theme_stylebox_override("hover", UITheme.box(RELAY.lightened(0.14), 7, Color.TRANSPARENT, 7))
	go.add_theme_stylebox_override("pressed", UITheme.box(RELAY.darkened(0.12), 7, Color.TRANSPARENT, 7))
	go.add_theme_color_override("font_hover_color", Color("112923"))
	go.add_theme_color_override("font_pressed_color", Color("112923"))
	go.add_theme_color_override("font_focus_color", Color("112923"))
	go.pressed.connect(func() -> void: _submit_address(_url.text))
	toolbar.add_child(go)
	cv.add_child(toolbar)
	_address_error = UITheme.wrap("", 12, UITheme.WARN)
	_address_error.hide()
	cv.add_child(_address_error)
	chrome.add_child(UITheme.margin(cv, 10))
	add_child(chrome)

	_panes = BoxContainer.new()
	_panes.add_theme_constant_override("separation", 0)
	_panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panes)
	_nav = UITheme.panel(Color("182127"), 0, 10)
	var nav_content := UITheme.vbox(7)
	_nav_title = UITheme.label(Game.L("즐겨찾기", "Bookmarks"), 12, Color("a4b2bd"))
	_nav_title.custom_minimum_size.y = 24
	nav_content.add_child(_nav_title)
	_tabs = GridContainer.new()
	_tabs.add_theme_constant_override("h_separation", 5)
	_tabs.add_theme_constant_override("v_separation", 5)
	nav_content.add_child(_tabs)
	_nav.add_child(nav_content)
	_panes.add_child(_nav)
	_body = UITheme.vbox(14)
	_surface = UITheme.panel(UITheme.BG1, 0, 0, Color.TRANSPARENT)
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = UITheme.scroll(UITheme.margin(_body, PAGE_MARGIN))
	_surface.add_child(_scroll)
	_panes.add_child(_surface)
	resized.connect(_update_layout)
	_surface.resized.connect(_update_page_layout)
	_update_layout()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	Game.chat_added.connect(func(m: Dictionary) -> void:
		if m["channel"] == "connectly" and _site == "connectly":
			_queue_refresh())
	Game.chat_updated.connect(func() -> void:
		if _site == "connectly":
			_queue_refresh())
	Game.wallet_changed.connect(func() -> void:
		if _site == "shop":
			_queue_refresh())
	_go("connectly" if int(Game.state["unread"].get("connectly", 0)) > 0 else "portal")


func current_site() -> Dictionary:
	for s in SITES:
		if s["id"] == _site:
			return s
	return SITES[0]


## True while a fun site is on screen (used by the boss walk-by check).
func is_slacking() -> bool:
	if _site == "video" and not _clip.is_empty():
		return _clip["fun"]
	return current_site()["fun"]


func _tick() -> void:
	if not is_visible_in_tree():
		return
	if desktop != null and desktop.top_window_app() != "browser":
		return
	if is_slacking():
		Game.change_condition(0.6)
		Game.inc_stat("slack_seconds")


func open_page(site: String) -> void:
	if SITES.any(func(entry: Dictionary) -> bool: return entry["id"] == site):
		_go(site)


func _go(route: String) -> void:
	if _history_index >= 0 and route == _route:
		_update_toolbar()
		return
	_history.resize(_history_index + 1)
	_history.append(route)
	_history_index = _history.size() - 1
	_show_route(route)


func _move_history(offset: int) -> void:
	var target := _history_index + offset
	if target >= 0 and target < _history.size():
		_history_index = target
		_show_route(_history[target])


func _show_route(route: String) -> void:
	_route = route
	_site = route.get_slice("/", 0)
	_clip = {}
	_clip_playing = false
	set_process(false)
	if _site == "video" and _route.contains("/"):
		var slug := _route.get_slice("/", 1)
		for index in Content.VIDEOS.size():
			if Content.VIDEOS[index]["id"] == slug:
				_clip = Content.VIDEOS[index]
				_clip_elapsed = 0.0
				_clip_playing = true
				set_process(true)
				Game.emit_event("video", {"video": index})
				break
	Game.emit_event("site", {"site": _site})
	_update_toolbar()
	_render()
	_scroll.scroll_vertical = 0


func _address() -> String:
	var path := _route.substr(_site.length())
	return "https://" + String(current_site()["url"]) + path


func _submit_address(text: String) -> void:
	var address := text.strip_edges().to_lower().trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
	for site in SITES:
		var host: String = site["url"]
		if address == host:
			_go(site["id"])
			return
		if address.begins_with(host + "/"):
			var records: Array = Content.ARTICLES if site["id"] == "news" else (Content.VIDEOS if site["id"] == "video" else [])
			var slug := address.trim_prefix(host + "/")
			for item in records:
				if item["id"] == slug:
					_go(String(site["id"]) + "/" + slug)
					return
	_address_error.text = Game.L("주소를 찾을 수 없어요. 아래 즐겨찾기에서 사이트를 선택하세요.", "Page not found. Choose a site from your bookmarks below.")
	_address_error.show()


func _update_toolbar() -> void:
	_url.text = _address()
	_address_mark.color = Color(current_site()["color"])
	_address_mark.queue_redraw()
	_address_error.hide()
	_back.disabled = _history_index <= 0
	_forward.disabled = _history_index >= _history.size() - 1
	_back.modulate.a = 0.45 if _back.disabled else 1.0
	_forward.modulate.a = 0.45 if _forward.disabled else 1.0


func _update_layout() -> void:
	var compact := size.x < COMPACT_WIDTH
	_panes.vertical = compact
	_nav.custom_minimum_size.x = 0.0 if compact else 144.0
	_nav_title.visible = not compact
	_tabs.columns = 4 if compact else 1


func _update_tile_columns() -> void:
	if not is_instance_valid(_tile_grid) or not _tile_grid.is_inside_tree():
		return
	var available := _surface.size.x - PAGE_MARGIN * 2 - 12
	if _site == "video" and available >= 682:
		_tile_grid.columns = 3
	else:
		_tile_grid.columns = 2 if available >= 450 else 1


func _update_page_layout() -> void:
	_update_tile_columns()
	if not is_instance_valid(_lead_photo) or not _lead_photo.is_inside_tree():
		return
	var compact := _surface.size.x < 570
	_lead_photo.custom_minimum_size = Vector2(105, 108) if compact else Vector2(252, 178)
	_lead_copy.custom_minimum_size.x = 160.0 if compact else 208.0
	_lead_title.add_theme_font_size_override("font_size", 18 if compact else 22)


func _queue_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_refresh.call_deferred(_route)


func _refresh(route: String) -> void:
	_refresh_pending = false
	if _route == route:
		_render()


func _browser_button(title: String, tooltip := "", accent := UITheme.TEXT2) -> Button:
	var button := Button.new()
	button.text = title
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = 30
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_stylebox_override("focus", UITheme.box(Color.TRANSPARENT, 5, RELAY))
	return button


func _toolbar_arrow(glyph: String, tooltip: String) -> Button:
	var button := _browser_button("", tooltip)
	button.custom_minimum_size = Vector2(36, 36)
	button.add_theme_stylebox_override("normal", UITheme.box(Color("26353e"), 7, SHELL_LINE))
	button.add_theme_stylebox_override("hover", UITheme.box(Color("30444d"), 7, RELAY))
	button.add_theme_stylebox_override("pressed", UITheme.box(Color("17252b"), 7, RELAY))
	var centered := CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(centered)
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centered.add_child(Icon.make(glyph, Color("d8e4ea"), 19))
	return button


func _render() -> void:
	UITheme.clear(_tabs)
	for s in SITES:
		var b := _browser_button(s["name"], "https://" + String(s["url"]))
		var sel: bool = s["id"] == _site
		var tint := Color(s["color"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
		b.add_theme_stylebox_override("normal", _site_button_style(Color(tint, 0.13) if sel else Color.TRANSPARENT, Color(tint, 0.39) if sel else Color.TRANSPARENT))
		b.add_theme_stylebox_override("hover", _site_button_style(Color(tint, 0.10), Color(tint, 0.23)))
		b.add_theme_stylebox_override("pressed", _site_button_style(Color(tint, 0.19), Color(tint, 0.42)))
		b.add_theme_color_override("font_color", tint.lightened(0.14) if sel else Color("c0cbd5"))
		var dot := Icon.make("dot", tint, 13)
		b.add_child(dot)
		dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		dot.offset_left = 6
		dot.offset_right = 19
		dot.offset_top = -6.5
		dot.offset_bottom = 6.5
		var unread := int(Game.state["unread"].get("connectly", 0))
		if s["id"] == "connectly" and unread > 0:
			b.text += "  (%d)" % unread
		var sid: String = s["id"]
		b.pressed.connect(_go.bind(sid))
		_tabs.add_child(b)
	var background := PAPER if _site == "news" else (Color("14111e") if _site == "video" else UITheme.BG1)
	_surface.add_theme_stylebox_override("panel", UITheme.box(background, 0))
	_tile_grid = null
	_lead_photo = null
	_lead_copy = null
	_lead_title = null
	UITheme.clear(_body)
	match _site:
		"portal":
			_portal()
		"connectly":
			_connectly()
		"news":
			_news()
		"video":
			_videos()
		"lounge":
			_lounge()
		"shop":
			_shop()
		"arcade":
			_body.add_child(Arcade.new())
		"moonlight":
			_body.add_child(preload("res://scripts/apps/page_view.gd").new())


func _site_button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := UITheme.box(fill, 6, edge, 4)
	style.content_margin_left = 23
	style.content_margin_right = 6
	return style


func _header(title: String, sub: String, color: Color) -> void:
	var h := UITheme.vbox(2)
	h.add_child(UITheme.bold(title, 22, color.lightened(0.2)))
	h.add_child(UITheme.wrap(sub, 13, UITheme.TEXT2))
	_body.add_child(h)


func _card() -> PanelContainer:
	var c := UITheme.panel(UITheme.BG2, 10, 14, Color(1, 1, 1, 0.05))
	_body.add_child(c)
	return c


# --- Sites --------------------------------------------------------------------------

func _portal() -> void:
	_header("NEXORA Portal", Game.L("사내 포털 · DAY %d", "Intranet · DAY %d") % Game.day(), Color("5b8cff"))
	var play := _browser_button(Game.L("Packet Run 체험하기  →", "Play Packet Run  →"), "arcade.test", Color("f1cd84"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.pressed.connect(_go.bind("arcade"))
	_body.add_child(play)
	var news := _card()
	var nv := UITheme.vbox(6)
	nv.add_child(UITheme.bold(Game.L("공지사항", "Announcements"), 14))
	for line in [
		Game.L("• 이번 주 금요일은 팀 회식입니다. (참석 여부는 Alex에게)", "• Team dinner this Friday. (RSVP to Alex)"),
		Game.L("• 보안 교육 미이수자는 이번 주까지 완료해 주세요.", "• Finish your security training by the end of the week."),
		Game.L("• 신규 입사자 %s 님을 환영합니다!", "• Welcome our new hire, %s!") % Game.pname(),
	]:
		nv.add_child(UITheme.wrap(line, 13, UITheme.TEXT2))
	news.add_child(nv)

	var menu := _card()
	var mv := UITheme.vbox(6)
	mv.add_child(UITheme.bold(Game.L("오늘의 구내식당", "Cafeteria today"), 14))
	var menus := [Game.L("제육볶음 · 된장국 · 계란말이", "Spicy pork · miso soup · rolled omelette"), Game.L("돈까스 · 우동 · 샐러드", "Pork cutlet · udon · salad"),
		Game.L("비빔밥 · 미역국 · 김치전", "Bibimbap · seaweed soup · kimchi pancake"), Game.L("치킨마요 · 어묵국 · 과일", "Chicken mayo bowl · fishcake soup · fruit")]
	mv.add_child(UITheme.wrap(menus[(Game.day() - 1) % menus.size()], 13, UITheme.TEXT2))
	menu.add_child(mv)

	var coffee := _card()
	var cv := UITheme.hbox(12)
	var cvv := UITheme.vbox(2)
	cvv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cvv.add_child(UITheme.bold(Game.L("탕비실 커피 브레이크", "Coffee break"), 14))
	cvv.add_child(UITheme.wrap(Game.L("15분 쉬고 컨디션 회복. (현재 컨디션 %d)", "Take 15 minutes and recover. (Condition %d)") % Game.condition(), 12, UITheme.TEXT2))
	cv.add_child(cvv)
	var btn := UITheme.button(Game.L("쉬러 가기", "Take a break"), "primary")
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var last := int(Game.state["flags"].get("coffee_at", -999))
	var ready := Game.minutes() - last >= 90 or Game.day() != int(Game.state["flags"].get("coffee_day", 0))
	btn.disabled = not ready
	if not ready:
		btn.text = Game.L("방금 쉬었어요", "Just had one")
	btn.pressed.connect(func() -> void:
		Game.state["flags"]["coffee_at"] = Game.minutes()
		Game.state["flags"]["coffee_day"] = Game.day()
		Game.advance(15)
		Game.change_condition(30 if Game.state["owned"].has("coffee_machine") else 15)
		Game.notify("browser", Game.L("커피 브레이크", "Coffee break"), Game.L("컨디션이 회복됐어요.", "Feeling refreshed."))
		_render())
	cv.add_child(btn)
	coffee.add_child(cv)


func _connectly() -> void:
	var c := Color("38bdf8")
	_header("Connectly", Game.L("커리어 네트워크", "Your professional network"), c)
	Game.mark_read("connectly")
	var prof := _card()
	var pr := UITheme.hbox(14)
	pr.add_child(UITheme.avatar("me", 54))
	var pv := UITheme.vbox(2)
	pv.add_child(UITheme.bold(Game.pname(), 17))
	pv.add_child(UITheme.label("%s · NEXORA" % Game.rank_name(), 13, UITheme.TEXT2))
	pv.add_child(UITheme.label(Game.L("1촌 %d명", "%d connections") % int(Game.state["connectly"].get("connections", 3)), 12, c))
	pr.add_child(pv)
	prof.add_child(pr)

	var skills := _card()
	var sv := UITheme.vbox(6)
	sv.add_child(UITheme.bold(Game.L("기술 추천", "Skill endorsements"), 14))
	var endorsed := false
	for pair in [["daniel", "Code review"], ["mina", "Testing"], ["sophie", "Git"], ["alex", "Communication"]]:
		if Game.rel(pair[0], "tech") >= 25 or Game.rel(pair[0], "work") >= 35:
			sv.add_child(UITheme.label(Game.L("✓ %s — %s 님이 추천", "✓ %s — endorsed by %s") % [pair[1], Game.npc_name(pair[0])], 13, UITheme.TEXT2))
			endorsed = true
	if not endorsed:
		sv.add_child(UITheme.label(Game.L("아직 추천이 없어요. 동료들의 신뢰를 쌓아 보세요.", "No endorsements yet. Earn your teammates' trust."), 13, UITheme.MUTED))
	skills.add_child(sv)

	_body.add_child(UITheme.bold(Game.L("메시지", "Messages"), 14))
	var any := false
	for m in Game.state["chat"]:
		if m["channel"] != "connectly":
			continue
		any = true
		var card := _card()
		var v := UITheme.vbox(6)
		var head := UITheme.hbox(8)
		if m["from"] != "me":
			head.add_child(UITheme.avatar(m["from"], 26))
		head.add_child(UITheme.bold(Game.npc_name(m["from"]), 13))
		head.add_child(UITheme.label(Game.npc_role(m["from"]), 11, UITheme.MUTED))
		v.add_child(head)
		v.add_child(UITheme.wrap(Game.tx(m["text"]), 13, UITheme.TEXT))
		if not (m["choices"] as Array).is_empty() and m["answered"] == "":
			for ch in m["choices"]:
				var b := UITheme.choice_button(Game.tx(ch["label"]))
				b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				var mid := int(m["id"])
				var cid: String = ch["id"]
				b.pressed.connect(func() -> void: Game.answer(mid, cid))
				v.add_child(b)
		card.add_child(v)
	if not any:
		_body.add_child(UITheme.label(Game.L("새 메시지가 없습니다.", "No messages."), 13, UITheme.MUTED))

	_body.add_child(UITheme.bold(Game.L("피드", "Feed"), 14))
	for post in [
		[Game.L("Daniel Park", "Daniel Park"), Game.L("좋은 PR은 작고, 설명이 자세하고, 테스트가 있습니다. 그게 전부예요.", "Good PRs are small, well described, and tested. That's it.")],
		["Brightloop", Game.L("백엔드 엔지니어를 채용합니다. 빠르게 성장하는 팀에서 함께해요! #hiring", "We're hiring backend engineers. Grow fast with us! #hiring")],
		[Game.L("Alex Kim", "Alex Kim"), Game.L("이번 분기 NEXORA Commerce Cloud 고객사가 2배가 됐습니다. 팀 모두 고마워요!", "NEXORA Commerce Cloud doubled its customers this quarter. Thanks, team!")],
	]:
		var card := _card()
		var v := UITheme.vbox(4)
		v.add_child(UITheme.bold(post[0], 13))
		v.add_child(UITheme.wrap(post[1], 13, UITheme.TEXT2))
		card.add_child(v)


func _photo(index: int, height: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size.y = height
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _art != null:
		var width := floorf(_art.get_width() / 2.0)
		var tile_height := floorf(_art.get_height() / 2.0)
		var origin := Vector2(index % 2 * width, floorf(index / 2.0) * tile_height)
		var tile := AtlasTexture.new()
		tile.atlas = _art
		tile.region = Rect2(origin + Vector2(3, 3), Vector2(width - 6, tile_height - 6))
		tile.filter_clip = true
		picture.texture = tile
	return picture


func _news_link(title: String, target: String) -> Button:
	var button := _browser_button(title, "", NEWS_ACCENT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_stylebox_override("normal", UITheme.box(Color("f8f5ed"), 4, Color("cfb8a6"), 7))
	button.add_theme_stylebox_override("hover", UITheme.box(Color("fff9ec"), 4, NEWS_ACCENT, 7))
	button.add_theme_stylebox_override("pressed", UITheme.box(Color("e8d9cd"), 4, NEWS_ACCENT, 7))
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.pressed.connect(_go.bind(target))
	return button


func _news() -> void:
	var masthead := UITheme.vbox(4)
	masthead.add_child(UITheme.bold("DevDaily", 33, INK))
	masthead.add_child(UITheme.wrap(Game.L("개발과 일에 관한 독립 매체", "An independent journal about software and work"), 13, INK_MUTED))
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = NEWS_ACCENT
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	masthead.add_child(rule)
	_body.add_child(masthead)
	var slug := _route.get_slice("/", 1)
	for article in Content.ARTICLES:
		if slug == article["id"]:
			_read_article(article)
			return
	for index in Content.ARTICLES.size():
		var article: Dictionary = Content.ARTICLES[index]
		var panel := UITheme.panel(Color("f8f5ed"), 6, 12, Color("d8cfc0"))
		var column := UITheme.vbox(8)
		column.add_child(UITheme.bold(Game.tx(article["desk"]), 11, NEWS_ACCENT))
		var title := UITheme.wrap(Game.tx(article["title"]), 22 if index == 0 else 17, INK)
		title.add_theme_font_override("font", UITheme.font(false, true))
		column.add_child(title)
		column.add_child(UITheme.wrap(Game.tx(article["summary"]), 14, INK_MUTED))
		column.add_child(_news_link(Game.L("기사 읽기  →", "Read article  →"), "news/" + String(article["id"])))
		if index == 0:
			var lead := HFlowContainer.new()
			lead.add_theme_constant_override("h_separation", 16)
			lead.add_theme_constant_override("v_separation", 12)
			_lead_photo = _photo(article["art"], 178)
			_lead_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lead_photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_lead_copy = column
			_lead_title = title
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lead.add_child(_lead_photo)
			lead.add_child(column)
			panel.add_child(lead)
		else:
			panel.add_child(column)
		_body.add_child(panel)
	_update_page_layout()


func _read_article(article: Dictionary) -> void:
	_body.add_child(_news_link(Game.L("← 기사 목록", "← All articles"), "news"))
	_body.add_child(UITheme.bold(Game.tx(article["desk"]), 11, NEWS_ACCENT))
	var headline := UITheme.wrap(Game.tx(article["title"]), 28, INK)
	headline.add_theme_font_override("font", UITheme.font(false, true))
	_body.add_child(headline)
	_body.add_child(UITheme.wrap(Game.tx(article["summary"]), 15, INK_MUTED))
	_body.add_child(UITheme.wrap("%s  ·  %s" % [article["by"], Game.L("읽는 데 %d분", "%d min read") % article["minutes"]], 12, INK_MUTED))
	_body.add_child(_photo(article["art"], 220))
	for paragraph in article["body"]:
		_body.add_child(UITheme.wrap(Game.tx(paragraph), 16, INK))


func _videos() -> void:
	var violet := Color("c7a9fa")
	if not _clip.is_empty():
		_watch_clip(violet)
		return
	_body.add_child(UITheme.bold("Streamly", 28, violet))
	_body.add_child(UITheme.wrap(Game.L("작업과 일상을 담은 짧은 포토 클립", "Short photo clips about work and everyday life"), 13, UITheme.TEXT2))
	var shelf := _new_tile_grid()
	for clip in Content.VIDEOS:
		var tile := UITheme.panel(Color("251f34"), 9, 10, Color("413153"))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var preview := UITheme.vbox(7)
		preview.add_child(_photo(clip["art"], 110))
		var title := UITheme.wrap(Game.tx(clip), 14, UITheme.TEXT)
		title.add_theme_font_override("font", UITheme.font(false, true))
		title.custom_minimum_size.y = 38
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.add_child(title)
		preview.add_child(UITheme.wrap("%s  ·  %s" % [clip["channel"], _timestamp(clip["duration"])], 12, UITheme.TEXT2))
		var play_button := _browser_button(Game.L("▶  재생", "▶  Play"), Game.tx(clip), violet)
		play_button.custom_minimum_size.y = 34
		play_button.pressed.connect(_go.bind("video/" + String(clip["id"])))
		preview.add_child(play_button)
		tile.add_child(preview)
		shelf.add_child(tile)
	_update_tile_columns()


func _new_tile_grid() -> GridContainer:
	_tile_grid = GridContainer.new()
	_tile_grid.add_theme_constant_override("h_separation", 12)
	_tile_grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(_tile_grid)
	return _tile_grid


func _watch_clip(violet: Color) -> void:
	var back := _browser_button(Game.L("← 둘러보기", "← Browse"), "", violet)
	back.pressed.connect(_go.bind("video"))
	var navigation := UITheme.hbox(10)
	navigation.add_child(back)
	var channel := UITheme.label("Streamly / " + String(_clip["channel"]), 13, violet)
	channel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(channel)
	_body.add_child(navigation)
	_body.add_child(UITheme.wrap(Game.tx(_clip), 22, UITheme.TEXT))
	_body.add_child(UITheme.wrap("%s  ·  %s" % [Game.L("%s 조회", "%s views") % _clip["views"], Game.L("포토 클립", "Photo clip")], 12, UITheme.TEXT2))
	var player := UITheme.panel(Color("1d182b"), 8, 10, Color("413153"))
	var stack := UITheme.vbox(8)
	stack.add_child(_photo(_clip["art"], 186))
	_clip_caption = UITheme.wrap("", 13, UITheme.TEXT)
	_clip_caption.custom_minimum_size.y = 30
	stack.add_child(_clip_caption)
	var controls := UITheme.hbox(8)
	_clip_toggle = _browser_button("", "", violet)
	_clip_toggle.custom_minimum_size.x = 68
	_clip_toggle.pressed.connect(_toggle_clip)
	controls.add_child(_clip_toggle)
	_clip_seek = HSlider.new()
	_clip_seek.max_value = float(_clip["duration"])
	_clip_seek.step = 0.1
	_clip_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_seek.value_changed.connect(_seek_clip)
	controls.add_child(_clip_seek)
	_clip_clock = UITheme.label("", 12, UITheme.TEXT2)
	controls.add_child(_clip_clock)
	stack.add_child(controls)
	player.add_child(stack)
	_body.add_child(player)
	_update_clip()


func _timestamp(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


func _toggle_clip() -> void:
	if _clip_elapsed >= float(_clip["duration"]):
		_clip_elapsed = 0.0
	_clip_playing = not _clip_playing
	set_process(_clip_playing)
	_update_clip()


func _seek_clip(seconds: float) -> void:
	_clip_elapsed = seconds
	if _clip_elapsed >= float(_clip["duration"]):
		_clip_playing = false
		set_process(false)
	_update_clip()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _clip_playing:
		return
	_clip_elapsed = minf(_clip_elapsed + delta, _clip["duration"])
	if _clip_elapsed >= float(_clip["duration"]):
		_clip_playing = false
		set_process(false)
	_update_clip()


func _update_clip() -> void:
	var length: float = _clip["duration"]
	var captions: Array = _clip["captions"]
	var index := mini(floori(_clip_elapsed / length * captions.size()), captions.size() - 1)
	_clip_caption.text = Game.tx(captions[index])
	_clip_seek.set_value_no_signal(_clip_elapsed)
	_clip_clock.text = "%s / %s" % [_timestamp(_clip_elapsed), _timestamp(length)]
	_clip_toggle.text = Game.L("일시정지", "Pause") if _clip_playing else Game.L("재생", "Play")


func _lounge() -> void:
	_header("Lounge", Game.L("익명 직장인 라운지 · 테크", "Anonymous workplace lounge · Tech"), Color("a3e635"))
	var posts: Array = [
		[Game.L("요즘 신입들 git 잘함?", "Do new grads know git these days?"), Game.L("우리 팀 신입은 rebase를 rm -rf 처럼 무서워함 ㅋㅋ", "Our new hire fears rebase like rm -rf lol"), 42],
		[Game.L("코드 리뷰에서 'nit:' 붙이는 문화 어떻게 생각함?", "Thoughts on prefixing review comments with 'nit:'?"), Game.L("사소한 건 사소하다고 말해 주는 게 서로 편하던데", "Labelling small stuff as small makes life easier for everyone"), 18],
	]
	if Game.day() >= 2:
		posts.push_front([Game.L("NEXORA 다니는 사람?", "Anyone at NEXORA?"), Game.L("신입이 첫날부터 PR 올렸다던데 요즘 신입들 무섭다", "Heard their new hire shipped a PR on day one. Kids these days"), 27])
	if Game.state["story"].has("d2_05"):
		posts.push_front([Game.L("닉네임 기능 넣었다가 이름이 undefined로 나옴", "Shipped a nickname feature, names turned into 'undefined'"), Game.L("어디라고는 말 안 하겠음… 테스트 돌리고 머지합시다", "Not naming names… run your tests before merging"), 64])
	if Game.state["monitor"]["status"].get("auth", "ok") == "down":
		posts.push_front([Game.L("지금 NEXORA 로그인 되는 사람?", "Can anyone log into NEXORA right now?"), Game.L("고객사인데 30초째 로딩 중… 장애인가요?", "Customer here, been loading for 30 seconds… outage?"), 121])
	if Game.stat("caught_slacking") > 0:
		posts.push_front([Game.L("근무 중에 라운지 하다 걸림", "Got caught browsing the lounge at work"), Game.L("뒤에서 시니어가 조용히 보고 있었음… 다들 조심", "A senior was quietly watching over my shoulder… be careful"), 88])
	for p in posts:
		var card := _card()
		var v := UITheme.vbox(4)
		v.add_child(UITheme.bold(p[0], 14))
		v.add_child(UITheme.wrap(p[1], 13, UITheme.TEXT2))
		v.add_child(UITheme.label(Game.L("댓글 %d", "%d comments") % p[2], 11, UITheme.MUTED))
		card.add_child(v)


func _shop() -> void:
	_header("Shoply", Game.L("데스크 셋업 · 잔액 %s", "Desk essentials · Balance %s") % Game.won(Game.money()), Color("7cc5ae"))
	_body.add_child(_photo(3, 158))
	var grid := _new_tile_grid()
	for it in ITEMS:
		var card := UITheme.panel(UITheme.BG2, 10, 12, Color(1, 1, 1, 0.05))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(6)
		var product_name := UITheme.wrap(Game.tx(it["name"]), 14, UITheme.TEXT)
		product_name.add_theme_font_override("font", UITheme.font(false, true))
		v.add_child(product_name)
		var description := UITheme.wrap(Game.tx(it["desc"]), 12, UITheme.TEXT2)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(description)
		var owned: bool = Game.state["owned"].has(it["id"])
		var b := UITheme.button(Game.L("구매함 ✓", "Owned ✓") if owned else Game.won(it["price"]), "default" if owned else "primary")
		b.custom_minimum_size.y = 36
		b.disabled = owned or Game.money() < int(it["price"])
		var iid: String = it["id"]
		var price: int = it["price"]
		b.pressed.connect(func() -> void:
			if not Game.state["owned"].has(iid) and Game.spend(price):
				Game.state["owned"][iid] = true
				Game.inc_stat("purchases")
				Game.emit_event("purchase", {"item": iid})
				Game.notify("browser", "Shoply", Game.L("주문 완료! 책상에 배송됐어요. (F2로 방을 둘러보세요)", "Order complete! It's on your desk now. (Press F2 to look around)"))
				_queue_refresh())
		v.add_child(b)
		card.add_child(v)
		grid.add_child(card)
	_update_tile_columns()
	_body.add_child(UITheme.label(Game.L("급여는 퇴근할 때 입금됩니다.", "Salary is paid when you clock out."), 12, UITheme.MUTED))
