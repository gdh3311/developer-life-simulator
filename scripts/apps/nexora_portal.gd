extends VBoxContainer
## NEXORA's intranet introduces the product through the systems and people the player works with.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Art := preload("res://scripts/ui/illustrations.gd")
const BLUE := Color("a9beff")
const SECTIONS := {
	"": {"ko": "홈", "en": "Home"},
	"start": {"ko": "첫 출근", "en": "First day"},
	"commerce": {"ko": "Commerce Cloud", "en": "Commerce Cloud"},
	"customers": {"ko": "고객 이야기", "en": "Customers"},
	"team": {"ko": "팀 디렉터리", "en": "Team"},
}

var section := ""
var navigate: Callable
var desktop: Control


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var heading := UITheme.hbox(10)
	heading.add_child(Art.icon_view(Art.website("portal"), 36))
	heading.add_child(UITheme.bold("NEXORA", 24, BLUE))
	add_child(heading)
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override("h_separation", 7)
	nav.add_theme_constant_override("v_separation", 6)
	add_child(nav)
	for slug in SECTIONS:
		var btn := UITheme.button(Game.tx(SECTIONS[slug]), "primary" if slug == section else "")
		btn.pressed.connect(navigate.bind("portal/" + slug if slug != "" else "portal"))
		nav.add_child(btn)
	match section:
		"start":
			_first_day()
		"commerce":
			_commerce()
		"customers":
			_customers()
		"team":
			_team()
		_:
			_home()


func _surface(title: String, body: String, lead := false) -> VBoxContainer:
	var panel := UITheme.panel(Color("17253f") if lead else Color("202736"), 10, 15, Color("3a527b") if lead else Color("313e50"))
	var text := UITheme.vbox(7)
	var headline := UITheme.wrap(title, 24 if lead else 16, BLUE if lead else UITheme.TEXT)
	headline.add_theme_font_override("font", UITheme.font(false, true))
	text.add_child(headline)
	text.add_child(UITheme.wrap(body, 14, UITheme.TEXT2))
	panel.add_child(text)
	add_child(panel)
	return text


func _button(parent: VBoxContainer, title: String, callback: Callable, primary := false) -> Button:
	var btn := UITheme.button(title + "  ↗", "primary" if primary else "")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _app(app: String, target := "") -> void:
	if desktop != null:
		desktop.open_resource(app, target)


func _home() -> void:
	var hero := _surface(Game.L("온라인 상점이 장사를 이어갈 수 있게", "Keep small shops selling"),
		Game.L("Commerce Cloud는 온라인 상점의 로그인, 주문, 결제를 처리합니다. 커머스팀은 이 세 기능을 운영하는 commerce-api를 개발합니다.",
			"Commerce Cloud handles sign-in, orders, and payments for online shops. The commerce team builds and runs the commerce-api repository behind all three."), true)
	_button(hero, Game.L("첫 출근 안내", "First-day guide"), navigate.bind("portal/start"), true)
	if Story.active != null:
		var today := _surface(Game.L("지금 맡은 일", "Your current work"), Story.active.title_text())
		_button(today, Game.L("TaskBoard 열기", "Open TaskBoard"), _app.bind("tasks"))
	var office := _surface(Game.L("사내 소식", "Around the office"),
		Game.L("%s 님을 환영합니다. 금요일 팀 저녁 모임 참석 여부는 Alex에게 알려 주세요.", "Welcome, %s. Let Alex know if you can make the team dinner on Friday.") % Game.pname())
	var menus := [Game.L("제육볶음 · 된장국 · 계란말이", "Spicy pork · miso soup · rolled omelette"),
		Game.L("돈까스 · 우동 · 샐러드", "Pork cutlet · udon · salad"),
		Game.L("비빔밥 · 미역국 · 김치전", "Bibimbap · seaweed soup · kimchi pancake"),
		Game.L("치킨마요 · 어묵국 · 과일", "Chicken mayo bowl · fishcake soup · fruit")]
	office.add_child(UITheme.wrap(Game.L("오늘의 구내식당 · ", "Cafeteria today · ") + menus[(Game.day() - 1) % menus.size()], 13, UITheme.TEXT2))
	var coffee := _surface(Game.L("탕비실", "Coffee break"), "")
	var condition := coffee.get_child(1) as Label
	var take_break := _button(coffee, Game.L("쉬러 가기", "Take a break"), func() -> void: _take_break(), true)
	_update_break(take_break, condition)
	take_break.pressed.connect(_update_break.bind(take_break, condition))
	var studio := _surface("NEXORA Arcade",
		Game.L("사내 제작팀이 배포한 웹 게임입니다. 팀 기본판을 플레이해 볼 수 있어요.", "The studio team's browser game. You can play the team's sample build."))
	_button(studio, Game.L("Packet Run 체험하기", "Play Packet Run"), navigate.bind("arcade"))


func _first_day() -> void:
	var hero := _surface(Game.L("%s 님의 첫 출근", "%s's first day") % Game.pname(),
		Game.L("소속은 Commerce Cloud 커머스팀입니다. 오늘은 동료에게 인사하고 저장소를 살펴본 뒤, 작은 변경을 만들어 Daniel에게 리뷰를 요청합니다.",
			"You're on the Commerce Cloud team. Today you'll meet your teammates, explore the repository, and send Daniel a small change for review."), true)
	_button(hero, Game.L("Alex의 메시지 보기", "Open Alex's messages"), _app.bind("chat", "dm:alex"), true)
	var product := _surface(Game.L("어떤 회사에 왔나요?", "What does NEXORA make?"),
		Game.L("손님이 주문을 누르면 상점은 포장할 상품과 결제 상태를 알아야 합니다. NEXORA는 상점이 이 일을 자기 쇼핑몰에서 할 수 있도록 공통 서버를 제공합니다. 달빛상점처럼 작은 팀도 이 서버를 사용합니다.",
			"When someone places an order, the shop needs to know what to pack and whether the payment went through. NEXORA provides the shared service behind those steps for shops like Moonlight."))
	_button(product, Game.L("Commerce Cloud 둘러보기", "Explore Commerce Cloud"), navigate.bind("portal/commerce"))
	var work := _surface(Game.L("오늘 내가 하는 일", "What you're doing today"),
		Game.L("오늘의 첫 PR은 README 한 줄을 고치는 일입니다. 앞으로 로그인 버그나 결제 장애를 맡을 때도 같은 저장소에서 브랜치를 열고, 변경을 확인하고, 리뷰를 받습니다.",
			"Your first PR edits one line of the README. When you're debugging sign-in or investigating a payment incident later, you'll branch, inspect changes, and request review in this same repository."))
	_button(work, Game.L("팀의 온보딩 가이드", "Read the team's onboarding guide"), _app.bind("wiki", "workflow"))
	_button(work, Game.L("저장소 README 열기", "Open the repository README"), _app.bind("ide", "README.md"))
	_button(work, Game.L("AICode로 저장소 조사", "Inspect the repository in AICode"), _app.bind("ai"))


func _commerce() -> void:
	_surface("Commerce Cloud",
		Game.L("상점마다 다른 화면 뒤에서 같은 서버가 움직입니다. 이 저장소에서는 로그인, 주문, 결제 세 영역부터 보게 됩니다.",
			"The same service sits behind many different storefronts. In this repository you'll start with sign-in, orders, and payments."), true)
	var auth := _surface(Game.L("로그인 · 누가 주문하나요?", "Sign-in · Who is ordering?"),
		Game.L("손님은 주문 전에 계정으로 로그인하고, 점주는 판매자 계정으로 주문 목록을 확인합니다. 인증이 실패하면 주문 페이지까지 갈 수 없습니다.",
			"Shoppers sign in before ordering and shop owners sign in to view their order list. When authentication fails, the order screen is out of reach."))
	_button(auth, "src/auth/login.ts", _app.bind("ide", "src/auth/login.ts"))
	var orders := _surface(Game.L("주문 · 무엇을 포장하나요?", "Orders · What gets packed?"),
		Game.L("상품과 수량이 주문으로 기록됩니다. 점주는 이 목록을 보고 재고를 빼고 포장을 시작합니다. 손님 화면과 점주 화면에서 같은 주문을 가리키는 게 중요합니다.",
			"Items and quantities become an order. The shop owner uses that list to allocate stock and start packing. The customer and the shop need to be looking at the same order."))
	_button(orders, "src/orders/orders.ts", _app.bind("ide", "src/orders/orders.ts"))
	var payments := _surface(Game.L("결제 · 돈이 들어왔나요?", "Payments · Did the payment go through?"),
		Game.L("결제 참조는 어떤 주문의 돈이 처리됐는지 확인할 때 쓰입니다. 결제 응답이 늦으면 고객 대응팀은 주문 번호와 결제 기록을 함께 확인합니다.",
			"A payment reference tells us what happened to funds for an order. When a response comes late, customer support checks the order number against the payment record."))
	_button(payments, "src/payments/payments.ts", _app.bind("ide", "src/payments/payments.ts"))


func _customers() -> void:
	var hero := _surface(Game.L("달빛상점", "Moonlight Tea Shop"),
		Game.L("차와 머그를 파는 작은 가게입니다. 출시일 저녁 주문이 몰리는 날에는 점주가 직접 재고를 세고 포장합니다. 주문 목록이 두 줄로 보이면 같은 상품을 두 번 포장할 수도 있어요.",
			"A small shop selling tea and mugs. On launch nights the owner counts stock and packs every order by hand. A duplicate order row can mean the same item gets packed twice."), true)
	var photo := TextureRect.new()
	photo.texture = Art.product("hero")
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size.y = 148
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(photo)
	if not PageStudio.release().is_empty():
		_button(hero, Game.L("공개된 예약 페이지 보기", "Open the live pre-order page"), navigate.bind("moonlight"), true)
	var case_note := _surface(Game.L("고객 문의에서 팀 업무까지", "From customer report to engineering ticket"),
		Game.L("손님이 ‘버튼은 한 번 눌렀는데 주문이 두 개예요’라고 하면 Yuri가 시각과 주문 번호를 묻습니다. 커머스팀은 그 기록을 받아 주문과 결제를 대조하고, 같은 상황을 테스트에서 재현합니다.",
			"If a customer says they clicked once but got two orders, Yuri asks for the time and order numbers. The commerce team checks those orders against their payments and reproduces the scenario in a test."))
	_button(case_note, Game.L("DevDaily에서 재전송 사례 읽기", "Read the retry case on DevDaily"), navigate.bind("news/retry"))


func _team() -> void:
	_surface(Game.L("Commerce Cloud 팀", "The Commerce Cloud team"),
		Game.L("제품 요구사항은 Alex, 백엔드 리뷰는 Daniel, 첫날 사용법은 Sophie, 버그 재현 조건은 Mina에게 물어보세요.",
			"Ask Alex about product requirements, Daniel about backend reviews, Sophie about day-one setup, and Mina about reproducing a bug."), true)
	var people := [
		["alex", Game.L("PM · 무엇을 언제 만들지 정리합니다.", "PM · Clarifies what we are building and when.")],
		["sophie", Game.L("개발자 · 점주 주문 목록을 만들고 새 팀원의 첫날을 돕습니다.", "Engineer · Builds the shop owner's order list and helps new teammates settle in.")],
		["daniel", Game.L("시니어 백엔드 · 첫 PR을 리뷰하고 운영 변경을 검토합니다.", "Senior backend · Reviews your first PR and checks production changes.")],
		["mina", Game.L("QA · 제보를 재현하고 어떤 조건에서 테스트가 실패하는지 찾습니다.", "QA · Reproduces reports and identifies the conditions that fail.")],
	]
	for person in people:
		var card := _surface(Game.npc_name(person[0]), person[1])
		_button(card, Game.L("메시지 열기", "Open messages"), _app.bind("chat", "dm:" + person[0]))


func _break_ready() -> bool:
	var last := int(Game.state["flags"].get("coffee_at", -999))
	return Game.minutes() - last >= 90 or Game.day() != int(Game.state["flags"].get("coffee_day", 0))


func _take_break() -> void:
	if not _break_ready():
		return
	Game.state["flags"]["coffee_at"] = Game.minutes()
	Game.state["flags"]["coffee_day"] = Game.day()
	Game.advance(15)
	Game.change_condition(30 if Game.state["owned"].has("coffee_machine") else 15)
	Game.notify("browser", Game.L("커피 브레이크", "Coffee break"), Game.L("컨디션이 회복됐어요.", "Feeling refreshed."))


func _update_break(button: Button, condition: Label) -> void:
	button.disabled = not _break_ready()
	button.text = Game.L("방금 쉬었어요", "Just had one") if button.disabled else Game.L("쉬러 가기", "Take a break")
	condition.text = Game.L("15분 쉬고 컨디션 회복. (현재 컨디션 %d)", "Take 15 minutes and recover. (Condition %d)") % Game.condition()
