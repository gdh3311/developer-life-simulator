extends VBoxContainer
## The production ticket lives in TaskBoard, separate from the playable product.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MINT := Color("a5ebd8")

var desktop: Control
var _start: Button
var _edit: Button
var _test: Button
var _review: Button
var _publish: Button
var _play: Button
var _state: Label
var _feedback: Label
var _checks: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var ticket := UITheme.panel(UITheme.BG2, 10, 16, UITheme.LINE)
	var stack := UITheme.vbox(8)
	stack.add_child(UITheme.label("%s  /  Packet Run" % ArcadeStudio.ISSUE, 12, MINT, true))
	stack.add_child(UITheme.bold(Game.L("출구가 너무 일찍 열립니다", "The exit unlocks too early"), 22))
	stack.add_child(UITheme.wrap(Game.L("패킷을 다 모으기 전에 출구가 열립니다. 출구 조건을 고치고, 패킷 2개와 벽이 있는 맵에 이동 한도 안의 경로가 있는지 자동 테스트로 확인해 주세요.", "The exit opens before players collect every packet. Fix the exit rule and run automated tests for a route within the move budget on a map with two packets and a wall."), 14, UITheme.TEXT2))
	_state = UITheme.wrap("", 13, MINT)
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
	_publish = _button(actions, Game.L("내부 출시", "Release internally"), func() -> void: ArcadeStudio.publish(), true)
	_play = _button(actions, Game.L("Arcade에서 배포판 열기", "Open release in Arcade"), func() -> void:
		if desktop != null:
			desktop.open_resource("browser", "arcade"))
	_checks = UITheme.vbox(6)
	add_child(_checks)
	_feedback = UITheme.wrap("", 13, UITheme.TEXT2)
	add_child(_feedback)
	ArcadeStudio.changed.connect(_refresh)
	_refresh()


func _button(row: Container, title: String, action: Callable, primary := false) -> Button:
	var button := UITheme.button(title, "primary" if primary else "default")
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _take_ticket() -> void:
	if ArcadeStudio.start_project():
		_open_editor()
	else:
		_feedback.text = Game.L("작업 파일을 만들 수 없습니다.", "Could not create the draft file.")


func _open_editor() -> void:
	if desktop != null:
		desktop.open_resource("ide", ArcadeStudio.SOURCE)


func _run_tests() -> void:
	await ArcadeStudio.run_tests()


func _request_review() -> void:
	await ArcadeStudio.request_review()


func _refresh() -> void:
	var has_source := ArcadeStudio.has_source()
	var released := ArcadeStudio.release()
	var has_release := not released.is_empty()
	var approved := not ArcadeStudio.approval().is_empty()
	_start.visible = not has_source
	_edit.visible = has_source
	_test.visible = has_source
	_review.visible = has_source
	_publish.visible = has_source
	_play.visible = has_release
	_test.disabled = ArcadeStudio.busy
	_review.disabled = not ArcadeStudio.can_request_review()
	_publish.disabled = not ArcadeStudio.can_release()
	var release_current: bool = has_release and has_source and released.get("revision", "") == ArcadeStudio.read_source().sha256_text()
	if release_current:
		_state.text = Game.L("출시됨 · 배포판은 Arcade에서 이용할 수 있습니다.", "Released · The approved version is available in Arcade.")
	elif approved:
		_state.text = Game.L("검토 승인 · 내부 출시 가능", "Review approved · Ready to release")
	elif not has_source:
		_state.text = Game.L("미배정", "Unassigned")
	else:
		_state.text = Game.L("코드 수정 → 자동 테스트 → 검토 → 출시", "Edit source → Run tests → Review → Release")
	UITheme.clear(_checks)
	for item in ArcadeStudio.test_results():
		_checks.add_child(UITheme.wrap(("✓  " if item["ok"] else "×  ") + Game.tx(item["label"]), 13, MINT if item["ok"] else UITheme.WARN))
	_feedback.text = Game.L("저장한 소스로 빌드하는 중…", "Building the saved source…") if ArcadeStudio.busy else ArcadeStudio.feedback
	_feedback.visible = not _feedback.text.is_empty()
