extends VBoxContainer
## Relay desk for comparing Aurora's shared samples and rehearsing the cutover.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Transfer := preload("res://scripts/services/aurora_transfer.gd")
const ACCENT := Color("c4b5fd")
const SURFACE := Color("1f1d34")
const BORDER := Color("393650")

var _body: VBoxContainer
var _feedback := ""


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_body = UITheme.vbox(12)
	add_child(_body)
	Story.objectives_changed.connect(_render)
	_render()


func _render() -> void:
	UITheme.clear(_body)
	var header := _section()
	header.add_child(UITheme.bold("Aurora Retail", 28, ACCENT))
	if Game.chapter() < 6:
		header.add_child(UITheme.wrap(Game.L("이관 작업대는 챕터 6에서 열립니다.", "The transfer desk opens in Chapter 6."), 13, UITheme.MUTED))
		return
	var source := Game.L("NEXORA · 보내는 팀", "NEXORA · Sending team")
	var destination := Game.L("Brightloop · 받는 팀", "Brightloop · Receiving team")
	header.add_child(UITheme.wrap("%s  →  %s" % [source, destination], 13, UITheme.TEXT2))
	header.add_child(UITheme.wrap(Game.L("내 담당: 수신 주문을 Brightloop 계정에 기록", "Your role: record incoming orders in Brightloop accounts") if Transfer.moved() else
		Game.L("내 담당: NEXORA 주문을 공용 형식으로 내보내기", "Your role: export NEXORA orders in the shared format"), 13, ACCENT))
	_receipt()
	if Story.status("c06_05") in ["active", "done"]:
		_rehearsal()
	if Story.status("c06_03") == "active":
		_samples()
		_contract()
	else:
		_contract()
		_samples()


func _section() -> VBoxContainer:
	var panel := UITheme.panel(SURFACE, 10, 14, BORDER)
	var column := UITheme.vbox(8)
	panel.add_child(column)
	_body.add_child(panel)
	return column


func _contract() -> void:
	var contract := _section()
	contract.add_child(UITheme.bold(Game.L("교환 계약 · 버전 1", "Exchange contract · version 1"), 17))
	contract.add_child(UITheme.wrap(Game.L("공용 주문 키는 판매자 코드와 주문 번호의 조합입니다. 금액은 원 단위 정수입니다.",
		"The shared order key combines the seller code and order number. Amounts are whole won."), 13, UITheme.TEXT2))
	contract.add_child(UITheme.wrap(Game.L("내보내기 · 내부 상점을 공용 코드로 바꾸고, 알 수 없는 상점은 제외합니다. 과거 주문의 환불 값이 비어 있으면 0원으로 보냅니다.",
		"Export · Map internal shops to shared codes and skip unknown shops. Export missing refunds on historical orders as zero."), 13, UITheme.TEXT2))
	contract.add_child(UITheme.wrap(Game.L("받아들이기 · 버전 1과 등록된 공용 코드만 받습니다. 같은 계정과 주문의 재전송은 가장 나중 값으로 갱신합니다.",
		"Import · Accept version 1 and registered shared codes only. Repeat deliveries for the same account and order use the latest values."), 13, UITheme.TEXT2))


func _samples() -> void:
	var samples := _section()
	samples.add_child(UITheme.bold(Game.L("주문 표본 · ORD-104", "Order sample · ORD-104"), 17))
	samples.add_child(UITheme.label(Game.L("NEXORA · 주문 원본", "NEXORA · Source orders"), 13, ACCENT))
	for order in Transfer.SAMPLES:
		samples.add_child(UITheme.wrap(Game.L("%s → %s · 결제 %s · 환불 %s", "%s → %s · paid %s · refunded %s") %
			[order["nexora"], order["seller"], Game.won(order["total"]), Game.won(order["refund"])], 13, UITheme.TEXT2))
	samples.add_child(UITheme.label(Game.L("Brightloop · 인수 계정 목록", "Brightloop · Receiving accounts"), 13, ACCENT))
	for i in range(Transfer.SAMPLES.size() - 1, -1, -1):
		var order: Dictionary = Transfer.SAMPLES[i]
		samples.add_child(UITheme.wrap("%s  →  %s" % [order["brightloop"], order["seller"]], 13, UITheme.TEXT2))
	if Story.status("c06_03") == "done":
		samples.add_child(UITheme.wrap(Game.L("대조 완료 · 두 판매자의 ORD-104를 각각 보존했습니다.", "Reconciled · both sellers' ORD-104 records were preserved."), 13, UITheme.OK))
	if Story.status("c06_03") != "active":
		return
	var selectors: Array[OptionButton] = []
	for order in Transfer.SAMPLES:
		var line := UITheme.hbox(8)
		var label := UITheme.label("%s / %s" % [order["seller"], order["order"]], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var select := OptionButton.new()
		select.add_item(Game.L("인수 계정 선택", "Select receiving account"))
		for row in Transfer.SAMPLES:
			select.add_item(row["brightloop"])
		select.set_item_disabled(0, true)
		select.selected = 0
		selectors.append(select)
		line.add_child(select)
		samples.add_child(line)
	var result := UITheme.wrap(_feedback, 13, UITheme.WARN)
	samples.add_child(result)
	var submit := UITheme.button(Game.L("두 주문 대조", "Reconcile both orders"), "primary")
	submit.pressed.connect(func() -> void:
		var first := selectors[0].get_item_text(selectors[0].selected)
		var second := selectors[1].get_item_text(selectors[1].selected)
		if not Transfer.reconcile(first, second):
			_feedback = Game.L("인수 계정이 표본과 일치하지 않습니다. 주문 번호 대신 판매자 코드를 비교해 보세요.",
				"The receiving accounts don't match the sample. Compare seller codes across the two rows.")
			result.text = _feedback
		else:
			_feedback = ""
			_render())
	samples.add_child(submit)


func _rehearsal() -> void:
	var lab := _section()
	lab.add_child(UITheme.bold(Game.L("전환·원복 리허설", "Cutover and rollback rehearsal"), 17))
	var run := Transfer.rehearsal()
	if run.is_empty():
		run = Transfer.new_run()
	var phase: String = run["phase"]
	var writes := "Brightloop" if phase in ["switched", "rollback"] else "NEXORA"
	lab.add_child(UITheme.wrap(Game.L("현재 주문 접수 · %s", "Current order intake · %s") % writes, 13, ACCENT))
	for side in [["NEXORA", "source"], ["Brightloop", "destination"]]:
		var records: Array = run[side[1]]
		lab.add_child(UITheme.wrap("%s  ·  %s" % [side[0], ", ".join(records)], 13, UITheme.TEXT2))
	if phase == "verified":
		_show_rehearsal_result(lab, run)
		return
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	match phase:
		"snapshot":
			lab.add_child(UITheme.wrap(Game.L("복제본을 뜬 뒤 NEXORA에 ORD-106이 들어왔습니다. 접수를 Brightloop로 넘기기 전에 어떻게 할까요?",
				"ORD-106 arrived at NEXORA after the snapshot. What should happen before Brightloop takes new orders?"), 13, UITheme.TEXT))
			_action(buttons, Game.L("변경분 적용 후 전환", "Apply changes, then switch"), "replay_delta")
			_action(buttons, Game.L("현재 복제본으로 전환", "Switch with the current snapshot"), "use_snapshot")
		"switched":
			lab.add_child(UITheme.wrap(Game.L("Brightloop가 접수를 맡았습니다. 전환 뒤 새 주문 한 건을 받아 봅니다.",
				"Brightloop is taking orders. Record a new order after the switch."), 13, UITheme.TEXT))
			_action(buttons, Game.L("ORD-107 접수", "Receive ORD-107"), "take_order")
		"rollback":
			lab.add_child(UITheme.wrap(Game.L("Brightloop에서 응답 지연이 발생했습니다. NEXORA로 접수를 되돌립니다.",
				"Brightloop is slow to respond. Move order intake back to NEXORA."), 13, UITheme.TEXT))
			_action(buttons, Game.L("새 주문을 되보낸 뒤 원복", "Copy the new order back, then roll back"), "flush_then_restore")
			_action(buttons, Game.L("접수 경로만 원복", "Roll back order intake only"), "restore")
	lab.add_child(buttons)


func _show_rehearsal_result(lab: VBoxContainer, run: Dictionary) -> void:
	if Transfer.passed(run):
		lab.add_child(UITheme.wrap(Game.L("검증 완료 · 전환 시 ORD-106, 원복 후 ORD-107을 확인했습니다.",
			"Verified · ORD-106 survived the switch and ORD-107 survived rollback."), 13, UITheme.OK))
		return
	if run["missing_at_switch"]:
		lab.add_child(UITheme.wrap(Game.L("전환 시 누락 · 복제본 이후 주문 ORD-106이 Brightloop에 없습니다.",
			"Missing at cutover · ORD-106 arrived after the snapshot and is absent from Brightloop."), 13, UITheme.WARN))
	if run["missing_at_rollback"]:
		lab.add_child(UITheme.wrap(Game.L("원복 후 누락 · 전환 뒤 받은 ORD-107이 NEXORA로 돌아오지 않았습니다.",
			"Missing after rollback · ORD-107 was received after the switch and never made it back to NEXORA."), 13, UITheme.WARN))
	_action(lab, Game.L("처음부터 다시 리허설", "Restart the rehearsal"), "retry")


func _action(container: Container, label: String, action: String) -> void:
	var b := UITheme.button(label)
	b.custom_minimum_size.y = 34
	b.pressed.connect(func() -> void:
		if Transfer.operate(action):
			_render())
	container.add_child(b)


func _receipt() -> void:
	var window: String = Game.state["flags"].get("c06_pilot_window", "")
	if window == "":
		return
	var record := _section()
	record.add_child(UITheme.bold(Game.L("파일럿 일정 · 두 회사 확인", "Pilot schedule · confirmed by both companies"), 17))
	record.add_child(UITheme.wrap(Game.L("금요일 10:00 · AUR-01 한 곳부터", "Friday 10:00 · AUR-01 only") if window == "friday" else
		Game.L("월요일 · 판매자 확인 후 시작", "Monday · starts after seller sign-off"), 13, ACCENT))
	record.add_child(UITheme.wrap("Mina Choi · NEXORA    /    Raon Lim · Brightloop", 13, UITheme.TEXT2))
