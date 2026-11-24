extends VBoxContainer
## TaskBoard ticket for the Moonlight pre-order page (PageStudio). Mirrors the Packet Run ticket.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MOON := Color("f4c95d")

var desktop: Control
var _start: Button
var _edit: Button
var _test: Button
var _review: Button
var _publish: Button
var _open: Button
var _state: Label
var _feedback: Label
var _checks: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var ticket := UITheme.panel(UITheme.BG2, 10, 16, UITheme.LINE)
	var stack := UITheme.vbox(8)
	stack.add_child(UITheme.label("%s  /  moonlight.shop" % PageStudio.ISSUE, 12, MOON, true))
	stack.add_child(UITheme.bold(Game.L("달빛상점 예약 판매 페이지", "Moonlight's pre-order page"), 22))
	stack.add_child(UITheme.wrap(Game.L("윤서진 대표가 고객에게 보여 줄 실제 페이지예요. 상품 3개 이상과 대체 텍스트, 쉼표가 들어간 가격, 남은 시간 문구, 품절·마감 시 예약 버튼 비활성을 만들고 공개하세요. 공개한 페이지는 Relay에서 직접 눌러 볼 수 있어요.",
		"A real page Seojin will show her customers. Add at least three products with alt text, prices with separators, time-left wording, and a pre-order button that turns off when sold out or closed. The released page is clickable in Relay."), 14, UITheme.TEXT2))
	_state = UITheme.wrap("", 13, MOON)
	stack.add_child(_state)
	ticket.add_child(stack)
	add_child(ticket)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	add_child(actions)
	_start = _button(actions, Game.L("업무 맡기", "Take ticket"), _take_ticket, true)
	_edit = _button(actions, Game.L("DevIDE에서 수정", "Edit in DevIDE"), _open_editor)
	_test = _button(actions, Game.L("자동 테스트", "Run tests"), _run_tests, true)
	_review = _button(actions, Game.L("Daniel에게 검토 요청", "Request Daniel's review"), _request_review)
	_publish = _button(actions, Game.L("공개", "Release"), func() -> void: PageStudio.publish(), true)
	_open = _button(actions, Game.L("Relay에서 페이지 열기", "Open the page in Relay"), func() -> void:
		if desktop != null:
			desktop.open_resource("browser", "moonlight"))
	_checks = UITheme.vbox(6)
	add_child(_checks)
	_feedback = UITheme.wrap("", 13, UITheme.TEXT2)
	add_child(_feedback)
	PageStudio.changed.connect(_refresh)
	_refresh()


func _button(row: Container, title: String, action: Callable, primary := false) -> Button:
	var button := UITheme.button(title, "primary" if primary else "default")
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _take_ticket() -> void:
	if PageStudio.start_project():
		_open_editor()
	else:
		_feedback.text = Game.L("작업 파일을 만들 수 없습니다.", "Could not create the draft file.")
		_feedback.visible = true


func _open_editor() -> void:
	if desktop != null:
		desktop.open_resource("ide", PageStudio.SOURCE)


func _run_tests() -> void:
	await PageStudio.run_tests()


func _request_review() -> void:
	await PageStudio.request_review()


func _refresh() -> void:
	var available := PageStudio.available()
	var has_source := PageStudio.has_source()
	var released := PageStudio.release()
	var approved := not PageStudio.approval().is_empty()
	_start.visible = available and not has_source
	for b in [_edit, _test, _review, _publish]:
		b.visible = has_source
	_open.visible = not released.is_empty()
	_test.disabled = PageStudio.busy
	_review.disabled = not PageStudio.can_request_review()
	_publish.disabled = not PageStudio.can_release()
	var current: bool = not released.is_empty() and has_source and released.get("revision", "") == PageStudio.read_source().sha256_text()
	if not available:
		_state.text = Game.L("챕터 3에서 열림", "Opens in Chapter 3")
	elif current:
		_state.text = Game.L("공개됨 · moonlight.shop", "Live · moonlight.shop")
	elif approved:
		_state.text = Game.L("검토 승인 · 공개 가능", "Review approved · Ready to release")
	elif not has_source:
		_state.text = Game.L("미배정", "Unassigned")
	else:
		_state.text = Game.L("코드 수정 → 자동 테스트 → 검토 → 공개", "Edit source → Run tests → Review → Release")
	UITheme.clear(_checks)
	for item in PageStudio.test_results():
		_checks.add_child(UITheme.wrap(("✓  " if item["ok"] else "×  ") + Game.tx(item["label"]), 13, MOON if item["ok"] else UITheme.WARN))
	_feedback.text = Game.L("저장한 소스로 빌드하는 중…", "Building the saved source…") if PageStudio.busy else PageStudio.feedback
	_feedback.visible = not _feedback.text.is_empty()
