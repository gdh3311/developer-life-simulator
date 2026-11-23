extends VBoxContainer
## Customer ticket, a reproduction plan, and a small actual-code experiment bench.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
var _ticket: VBoxContainer
var _result: VBoxContainer
var _network: OptionButton
var _retry: CheckButton
var _keys: OptionButton
var _clicks: OptionButton
var _version: OptionButton
var _timing: OptionButton
var _run: Button
var _error: Label
var _plan_fields := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UITheme.bold(Game.L("Request Lab · 달빛상점", "Request Lab · Moonlight"), 19))
	add_child(UITheme.wrap(Game.L("가상 응답 조건을 바꾸고 실제 주문 함수를 실행합니다. 주문은 실험용이며 실제 결제는 하지 않습니다.", "Vary virtual response conditions and run the actual order function. Orders are simulated; no real payments."), 12, UITheme.TEXT2))
	if not RequestLab.available():
		add_child(UITheme.wrap(Game.L("챕터 2에서 첫 고객 업무를 맡으면 열립니다.", "Available when you take your first customer task in Chapter 2."), 14, UITheme.MUTED))
		return
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_ticket = UITheme.vbox(10)
	var ticket_scroll := UITheme.scroll(UITheme.margin(_ticket, 14))
	ticket_scroll.name = Game.L("지원 티켓", "Support ticket")
	tabs.add_child(ticket_scroll)
	var experiment := UITheme.vbox(10)
	var experiment_scroll := UITheme.scroll(UITheme.margin(experiment, 14))
	experiment_scroll.name = Game.L("요청 실험", "Experiments")
	tabs.add_child(experiment_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	experiment.add_child(grid)
	_network = _option(grid, Game.L("응답 조건", "Response"), [Game.L("즉시 응답", "Immediate"), Game.L("응답 지연", "Delayed")])
	_retry = CheckButton.new()
	_retry.text = Game.L("응답이 늦으면 한 번 재전송", "Resend once if response is late")
	_retry.button_pressed = true
	grid.add_child(UITheme.label(Game.L("재시도", "Retry"), 13))
	grid.add_child(_retry)
	_keys = _option(grid, Game.L("요청 키", "Request keys"), [Game.L("같은 키 유지", "Reuse the same key"), Game.L("매번 새 키", "New key each time")])
	_clicks = _option(grid, Game.L("구매 클릭", "Purchase clicks"), ["1", "2"])
	_version = _option(grid, Game.L("실행 코드", "Run version"), [Game.L("현재 작업 코드", "Current working code"), Game.L("신고된 버전", "Reported version")])
	if _concurrency_unlocked():
		_timing = _option(grid, Game.L("요청 타이밍", "Request timing"), [Game.L("순차 (응답 뒤 재전송)", "Sequential (resend after reply)"), Game.L("동시 (요청이 겹침)", "Concurrent (requests overlap)")])
	var previous: Dictionary = RequestLab.state()["latest"].get("config", {})
	_network.select(1 if previous.get("network", "fast") == "slow" else 0)
	_retry.button_pressed = previous.get("retry", true)
	_keys.select(1 if previous.get("keys", "same") == "new" else 0)
	_clicks.select(clampi(int(previous.get("clicks", 1)) - 1, 0, 1))
	_version.select(1 if previous.get("version", "current") == "reported" else 0)
	if _timing != null:
		_timing.select(1 if previous.get("timing", "sequential") == "concurrent" else 0)
	_run = UITheme.button(Game.L("조건대로 실험 실행", "Run this experiment"), "primary")
	_run.custom_minimum_size.y = 38
	_run.focus_mode = Control.FOCUS_ALL
	_run.pressed.connect(_run_probe)
	experiment.add_child(_run)
	_error = UITheme.wrap("", 13, UITheme.WARN)
	experiment.add_child(_error)
	_result = UITheme.vbox(8)
	experiment.add_child(_result)
	RequestLab.changed.connect(_refresh)
	Story.objectives_changed.connect(_refresh)
	tabs.tab_changed.connect(func(index: int) -> void:
		if index == 0:
			RequestLab.open_ticket())
	if Story.status("c02_08") != "locked":
		var reply := preload("res://scripts/apps/reply_composer.gd").new()
		reply.name = Game.L("고객 답장", "Customer reply")
		tabs.add_child(reply)
	if Story.active != null and Story.active.id == "c02_08":
		tabs.current_tab = tabs.get_tab_count() - 1
	elif Story.active != null and Story.active.id != "c02_01":
		tabs.current_tab = 1
	RequestLab.open_ticket()
	_render_ticket()
	_refresh()


func _option(grid: GridContainer, title: String, labels: Array) -> OptionButton:
	grid.add_child(UITheme.label(title, 13, UITheme.TEXT2))
	var control := OptionButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_mode = Control.FOCUS_ALL
	for label in labels:
		control.add_item(label)
	grid.add_child(control)
	return control


func _render_ticket() -> void:
	UITheme.clear(_ticket)
	_ticket.add_child(UITheme.bold("NXR-021 · " + Game.L("주문이 두 번 들어왔어요", "An order appeared twice"), 17))
	_ticket.add_child(UITheme.wrap(Game.L("달빛상점 · 윤서진\n“어제 저녁 같은 분 주문이 두 개 들어왔어요. 결제는 하나 같기도 하고요. 바빠서 하나 지우고 보냈는데 오늘도 그러면 곤란해서요.”",
		"Moonlight · Seojin Yun\n“Two orders from the same customer came in last night. I think there was one payment. I removed one because we were busy. Could you look into it?”"), 14, UITheme.TEXT))
	_ticket.add_child(UITheme.wrap(Game.L("받은 정보: 주문 ML-1042, 어제 18시 무렵. 같은 구매 시도인지, 응답이 늦었는지 아직 모릅니다.", "Received: order ML-1042, around 18:00 yesterday. We do not yet know whether this was one purchase attempt or a delayed response."), 12, UITheme.MUTED))
	var inspect := UITheme.button(Game.L("사내 요청 기록 확인", "Inspect internal request records"))
	inspect.pressed.connect(func() -> void:
		RequestLab.inspect_records()
		_render_ticket())
	_ticket.add_child(inspect)
	if RequestLab.state()["evidence"]:
		_ticket.add_child(UITheme.wrap("18:04:11.000  request=buy-17  order=ML-1042  payment=pay-8\n18:04:11.700  request=buy-17  order=ML-1043  payment=pay-8", 12, UITheme.ACCENT.lightened(0.3)))
		_ticket.add_child(UITheme.wrap(Game.L("같은 요청 키, 700ms 간격, 서로 다른 주문 번호입니다. 같은 결제 참조만으로 승인 횟수까지 단정하지는 않습니다.", "The same request key produced different order IDs, 700ms apart. A shared payment reference alone does not establish the number of charges."), 12, UITheme.TEXT2))
	_ticket.add_child(UITheme.bold(Game.L("무엇을 고정하고 비교할까요?", "What will you hold constant and compare?"), 14))
	_plan_fields.clear()
	for pair in [["request", Game.L("같은 구매 시도의 요청 키", "The request key for one purchase attempt")], ["retries", Game.L("같은 요청의 전송 횟수와 지연", "Resend count and delay for that request")], ["payment", Game.L("결제 상태는 별도 확인", "Verify payment status separately")]]:
		var field := CheckButton.new()
		field.text = pair[1]
		field.button_pressed = pair[0] in RequestLab.state()["plan"]
		_plan_fields[pair[0]] = field
		_ticket.add_child(field)
	var plan := UITheme.button(Game.L("재현 계획 기록", "Record reproduction plan"), "primary")
	plan.disabled = not RequestLab.state()["evidence"]
	var feedback := UITheme.wrap("", 12, UITheme.WARN)
	plan.pressed.connect(func() -> void:
		var fields: Array = _plan_fields.keys().filter(func(key) -> bool: return _plan_fields[key].button_pressed)
		var accepted := RequestLab.save_plan(fields)
		feedback.text = Game.L("요청 키와 재전송 조건을 기준으로 실험을 비교합니다.", "Compare experiments using the request key and resend conditions.") if accepted else Game.L("같은 요청인지와 몇 번 전송됐는지를 먼저 비교해 보세요.", "First compare whether it was the same request and how often it was sent."))
	_ticket.add_child(plan)
	_ticket.add_child(feedback)


func _run_probe() -> void:
	_error.text = ""
	var result := await RequestLab.run_probe({"network": "fast" if _network.selected == 0 else "slow", "retry": _retry.button_pressed, "keys": "same" if _keys.selected == 0 else "new", "clicks": _clicks.selected + 1, "version": "current" if _version.selected == 0 else "reported", "timing": "concurrent" if _timing != null and _timing.selected == 1 else "sequential"})
	if not is_instance_valid(_error):
		return
	if not result.get("ok", false):
		_error.text = String(result.get("error", ""))
	_refresh()


func _refresh() -> void:
	if _run == null:
		return
	_run.disabled = RequestLab.busy or Game.state["day_done"]
	for control in [_network, _keys, _clicks, _version, _timing]:
		if control != null:
			control.disabled = RequestLab.busy
	_retry.disabled = RequestLab.busy
	UITheme.clear(_result)
	var latest: Dictionary = RequestLab.state()["latest"]
	if latest.is_empty():
		_result.add_child(UITheme.wrap(Game.L("먼저 즉시 응답과 지연 응답을 비교해 보세요. 신고된 버전은 수정 전 원인을 다시 재현할 때 쓸 수 있습니다.", "Compare immediate and delayed responses. Use the reported version to reproduce the original behavior after editing your code."), 13, UITheme.TEXT2))
		return
	var calls := int(latest["attempts"])
	var orders := int(latest["created"])
	_result.add_child(UITheme.bold(Game.L("호출 %d번 → 주문 %d개" % [calls, orders], "%d %s → %d %s" % [calls, "call" if calls == 1 else "calls", orders, "order" if orders == 1 else "orders"]), 22, UITheme.ACCENT.lightened(0.3)))
	_result.add_child(UITheme.label(String(latest["time"]) + " · " + (Game.L("실행 당시 작업 코드", "Working code at time of run") if latest["config"]["version"] == "current" else Game.L("신고된 버전", "Reported version")), 12, UITheme.MUTED))
	_result.add_child(UITheme.wrap(_conditions(latest["config"]), 12, UITheme.TEXT2))
	for response in latest["responses"]:
		_result.add_child(UITheme.label("+%dms  %s  →  %s" % [int(response["virtualMs"]), response["key"], response["orderId"]], 12, UITheme.TEXT2))
	if latest["config"].get("timing", "sequential") == "concurrent":
		_result.add_child(UITheme.wrap(Game.L("동시 요청: 같은 키의 요청이 겹쳐 들어와도 주문은 하나여야 합니다. '있는지 확인 → 만들기'를 따로 하면 둘 다 '없음'을 보고 각자 만듭니다.", "Concurrent: overlapping requests with the same key must still create one order. Checking and creating as separate steps lets both see 'nothing yet' and each create one."), 12, UITheme.TEXT2))
	else:
		_result.add_child(UITheme.wrap(Game.L("같은 키를 유지한 순차 재전송은 같은 주문이어야 합니다. 매번 새 키를 쓰면 다른 구매 시도입니다.", "Sequential resends with the same key should return one order. New keys are separate purchase attempts.") + ("" if _concurrency_unlocked() else Game.L(" 동시 요청은 아직 검증하지 않았습니다.", " Concurrent requests have not been tested.")), 12, UITheme.TEXT2))
	_result.add_child(UITheme.label(Game.L("최근 실험 기록", "Recent experiments"), 12, UITheme.MUTED))
	var history: Array = RequestLab.state()["runs"]
	for index in range(maxi(0, history.size() - 4), history.size()):
		var run: Dictionary = history[index]
		_result.add_child(UITheme.wrap("%s  %s · %s  → %d / %d" % [run["time"], Game.L("현재", "current") if run["config"]["version"] == "current" else Game.L("신고", "reported"), _conditions(run["config"]), int(run["attempts"]), int(run["created"])], 11, UITheme.MUTED))


func _concurrency_unlocked() -> bool:
	return Story.status("c02_06") != "locked"


func _conditions(config: Dictionary) -> String:
	var timing := (Game.L(" · 동시", " · concurrent") if config.get("timing", "sequential") == "concurrent" else "")
	return timing.trim_prefix(" · ") + (" · " if timing != "" else "") + "%s · %s · %s · %s" % [
		Game.L("응답 지연", "Delayed") if config["network"] == "slow" else Game.L("즉시 응답", "Immediate"),
		Game.L("재전송 켬", "Retry on") if config["retry"] else Game.L("재전송 끔", "Retry off"),
		Game.L("같은 키", "Same key") if config["keys"] == "same" else Game.L("새 키", "New keys"),
		Game.L("클릭 %d회" % int(config["clicks"]), "%d %s" % [int(config["clicks"]), "click" if int(config["clicks"]) == 1 else "clicks"]),
	]
