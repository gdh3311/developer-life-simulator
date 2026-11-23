extends VBoxContainer
## Web browser: the company portal plus sites for slacking off (news, videos, an anonymous
## lounge, shopping) and Connectly, a professional network where recruiters reach out.
## Fun sites restore condition — but a boss walking by might see the screen.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const SITES := [
	{"id": "portal", "name": "NEXORA Portal", "url": "intranet.nexora.dev", "fun": false, "color": "5b8cff"},
	{"id": "connectly", "name": "Connectly", "url": "connectly.com/in/me", "fun": false, "color": "38bdf8"},
	{"id": "news", "name": "DevDaily", "url": "devdaily.io", "fun": true, "color": "f97316"},
	{"id": "video", "name": "Streamly", "url": "streamly.tv", "fun": true, "color": "ef4444"},
	{"id": "lounge", "name": "Lounge", "url": "lounge.anon/tech", "fun": true, "color": "a3e635"},
	{"id": "shop", "name": "Shoply", "url": "shoply.shop", "fun": true, "color": "f472b6"},
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

const VIDEOS := [
	{"ko": "10분 만에 이해하는 Git 내부 구조", "en": "Git internals in 10 minutes", "fun": false},
	{"ko": "고양이가 키보드 위에서 배포함 (실화)", "en": "Cat deploys to production by walking on keyboard", "fun": true},
	{"ko": "개발자 출근 브이로그 | 커피 4잔", "en": "Dev day-in-the-life vlog | 4 coffees", "fun": true},
	{"ko": "시니어 개발자가 코드 리뷰에서 하는 말 모음", "en": "Things senior devs say in code review", "fun": true},
	{"ko": "로파이 코딩 음악 3시간", "en": "3 hours of lo-fi coding beats", "fun": true},
]

var desktop: Control
var _site := "portal"
var _url: Label
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _timer: Timer
var _video := -1
var _video_progress := 0.0
var _video_bar: Control


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var chrome := UITheme.panel(UITheme.BG2, 0, 8, Color(0, 0, 0, 0))
	var cv := UITheme.vbox(6)
	_tabs = UITheme.hbox(4)
	cv.add_child(_tabs)
	var addr := UITheme.panel(UITheme.BG0, 14, 6, UITheme.LINE)
	var ar := UITheme.hbox(8)
	ar.add_child(Icon.make("ring", UITheme.OK, 10))
	_url = UITheme.label("", 12, UITheme.TEXT2)
	ar.add_child(_url)
	addr.add_child(ar)
	cv.add_child(addr)
	chrome.add_child(cv)
	add_child(chrome)
	_body = UITheme.vbox(12)
	_scroll = UITheme.scroll(UITheme.margin(_body, 18))
	add_child(_scroll)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	Game.chat_added.connect(func(m: Dictionary) -> void:
		if m["channel"] == "connectly" and _site == "connectly":
			_render())
	Game.chat_updated.connect(func() -> void:
		if _site == "connectly":
			_render())
	Game.wallet_changed.connect(func() -> void:
		if _site == "shop":
			_render())
	if int(Game.state["unread"].get("connectly", 0)) > 0:
		_site = "connectly"
	_render()


func current_site() -> Dictionary:
	for s in SITES:
		if s["id"] == _site:
			return s
	return SITES[0]


## True while a fun site is on screen (used by the boss walk-by check).
func is_slacking() -> bool:
	if _site == "video" and _video >= 0:
		return VIDEOS[_video]["fun"]
	return current_site()["fun"]


func _tick() -> void:
	if not is_visible_in_tree():
		return
	if is_slacking():
		Game.change_condition(0.6)
		Game.inc_stat("slack_seconds")
	if _video >= 0 and is_instance_valid(_video_bar):
		_video_progress = fmod(_video_progress + 0.012, 1.0)
		_video_bar.queue_redraw()


func _go(id: String) -> void:
	_site = id
	_video = -1
	Game.emit_event("site", {"site": id})
	_render()


func _render() -> void:
	UITheme.clear(_tabs)
	for s in SITES:
		var b := Button.new()
		b.text = s["name"]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sel: bool = s["id"] == _site
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG1 if sel else Color(0, 0, 0, 0), 6, Color(s["color"]) if sel else Color(0, 0, 0, 0), 6))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.05), 6, Color(0, 0, 0, 0), 6))
		b.add_theme_color_override("font_color", UITheme.TEXT if sel else UITheme.MUTED)
		b.add_theme_font_size_override("font_size", 12)
		var unread := int(Game.state["unread"].get("connectly", 0))
		if s["id"] == "connectly" and unread > 0:
			b.text += "  (%d)" % unread
		var sid: String = s["id"]
		b.pressed.connect(_go.bind(sid))
		_tabs.add_child(b)
	_url.text = "https://" + String(current_site()["url"])
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
	_scroll.scroll_vertical = 0


func _header(title: String, sub: String, color: Color) -> void:
	var h := UITheme.vbox(2)
	h.add_child(UITheme.bold(title, 22, color.lightened(0.2)))
	h.add_child(UITheme.label(sub, 12, UITheme.MUTED))
	_body.add_child(h)


func _card() -> PanelContainer:
	var c := UITheme.panel(UITheme.BG2, 10, 14, Color(1, 1, 1, 0.05))
	_body.add_child(c)
	return c


# --- Sites --------------------------------------------------------------------------

func _portal() -> void:
	_header("NEXORA Portal", Game.L("사내 포털 · DAY %d", "Intranet · DAY %d") % Game.day(), Color("5b8cff"))
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
	mv.add_child(UITheme.label(menus[(Game.day() - 1) % menus.size()], 13, UITheme.TEXT2))
	menu.add_child(mv)

	var coffee := _card()
	var cv := UITheme.hbox(12)
	var cvv := UITheme.vbox(2)
	cvv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cvv.add_child(UITheme.bold(Game.L("탕비실 커피 브레이크", "Coffee break"), 14))
	cvv.add_child(UITheme.label(Game.L("15분 쉬고 컨디션 회복. (현재 컨디션 %d)", "Take 15 minutes and recover. (Condition %d)") % Game.condition(), 12, UITheme.MUTED))
	cv.add_child(cvv)
	var btn := UITheme.button(Game.L("쉬러 가기", "Take a break"), "primary")
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
				var b := UITheme.button(Game.tx(ch["label"]), "primary")
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


func _news() -> void:
	_header("DevDaily", Game.L("개발자 뉴스", "News for developers"), Color("f97316"))
	var items := [
		[Game.L("\"테스트 없는 금요일 배포\" 설문, 응답자 73%가 '절대 안 함'", "Survey: 73% would 'never' deploy untested code on a Friday"), Game.L("나머지 27%는 '이미 해 봤고 후회함'이라고 답했다.", "The other 27% said 'already did it, regret it'.")],
		[Game.L("AI 코딩 에이전트, 생산성은 올렸지만 리뷰 시간도 늘었다", "AI coding agents boost output, but review time grows too"), Game.L("전문가들은 'AI가 쓴 코드도 사람이 쓴 코드처럼 리뷰하라'고 조언한다.", "Experts advise reviewing AI code like any human-written code.")],
		[Game.L("Git 3.0 로드맵 공개… 기본 브랜치 이름은 그대로", "Git 3.0 roadmap published… default branch name unchanged"), Game.L("커뮤니티는 대체로 환영하는 분위기.", "The community mostly welcomes it.")],
		[Game.L("주니어 개발자가 가장 많이 하는 실수 1위: main에 직접 push", "Top junior mistake: pushing straight to main"), Game.L("2위는 'PR 설명 비워 두기'.", "Number two: leaving the PR description empty.")],
	]
	for it in items:
		var card := _card()
		var v := UITheme.vbox(4)
		v.add_child(UITheme.bold(it[0], 14))
		v.add_child(UITheme.wrap(it[1], 13, UITheme.TEXT2))
		card.add_child(v)


func _videos() -> void:
	_header("Streamly", Game.L("지금 뜨는 영상", "Trending now"), Color("ef4444"))
	if _video >= 0:
		var player := PanelContainer.new()
		player.add_theme_stylebox_override("panel", UITheme.box(Color("000000"), 10, Color(0, 0, 0, 0), 0))
		player.custom_minimum_size.y = 230
		var art := Control.new()
		art.custom_minimum_size.y = 230
		var vid: int = _video
		art.draw.connect(func() -> void:
			var w := art.size.x
			var h := art.size.y
			var hue := float(vid) / VIDEOS.size()
			art.draw_rect(Rect2(0, 0, w, h), Color.from_hsv(hue, 0.5, 0.25))
			for i in 6:
				var x := fmod(_video_progress * w * 3.0 + i * w / 6.0, w)
				art.draw_circle(Vector2(x, h * 0.5 + sin(_video_progress * 20.0 + i) * 40.0), 18 + i * 3, Color.from_hsv(fmod(hue + i * 0.1, 1.0), 0.6, 0.8, 0.5))
			art.draw_rect(Rect2(16, h - 16, w - 32, 4), Color(1, 1, 1, 0.2))
			art.draw_rect(Rect2(16, h - 16, (w - 32) * _video_progress, 4), Color("ef4444")))
		_video_bar = art
		player.add_child(art)
		_body.add_child(player)
		_body.add_child(UITheme.bold(Game.tx(VIDEOS[_video]), 16))
		_body.add_child(UITheme.label(Game.L("조회수 %d만회", "%dK views") % (37 + _video * 11), 12, UITheme.MUTED))
	for i in VIDEOS.size():
		var b := Button.new()
		b.text = "▶  " + Game.tx(VIDEOS[i])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG2, 8, Color(0, 0, 0, 0), 10))
		b.add_theme_stylebox_override("hover", UITheme.box(UITheme.BG3, 8, Color(0, 0, 0, 0), 10))
		var idx := i
		b.pressed.connect(func() -> void:
			_video = idx
			_video_progress = 0.0
			Game.emit_event("video", {"video": idx})
			_render())
		_body.add_child(b)


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
	_header("Shoply", Game.L("데스크 셋업 특가 · 잔액 %s", "Desk setup deals · Balance %s") % Game.won(Game.money()), Color("f472b6"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for it in ITEMS:
		var card := UITheme.panel(UITheme.BG2, 10, 12, Color(1, 1, 1, 0.05))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(6)
		v.add_child(UITheme.bold(Game.tx(it["name"]), 14))
		v.add_child(UITheme.wrap(Game.tx(it["desc"]), 12, UITheme.TEXT2))
		var owned: bool = Game.state["owned"].has(it["id"])
		var b := UITheme.button(Game.L("구매함 ✓", "Owned ✓") if owned else Game.won(it["price"]), "default" if owned else "primary")
		b.disabled = owned or Game.money() < int(it["price"])
		var iid: String = it["id"]
		var price: int = it["price"]
		b.pressed.connect(func() -> void:
			if Game.spend(price):
				Game.state["owned"][iid] = true
				Game.inc_stat("purchases")
				Game.emit_event("purchase", {"item": iid})
				Game.notify("browser", "Shoply", Game.L("주문 완료! 책상에 배송됐어요. (F2로 방을 둘러보세요)", "Order complete! It's on your desk now. (Press F2 to look around)"))
				_render())
		v.add_child(b)
		card.add_child(v)
		grid.add_child(card)
	_body.add_child(grid)
	_body.add_child(UITheme.label(Game.L("급여는 퇴근할 때 입금됩니다.", "Salary is paid when you clock out."), 12, UITheme.MUTED))
