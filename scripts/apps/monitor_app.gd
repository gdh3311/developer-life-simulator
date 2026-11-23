extends VBoxContainer
## Monitor: production service status, error-rate chart and a live log stream.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

const SERVICES := [["api", "commerce-api"], ["auth", "auth-service"], ["payments", "payments"]]
const LOGS := {
	"order_duplicates": ["[c=#f5a524]WARN[/c] orders.create request=buy-17 order=ML-1042", "[c=#f5a524]WARN[/c] orders.create request=buy-17 order=ML-1043 +700ms", "[c=#3ddc84]200[/c] payments.lookup ref=pay-8 verification=pending"],
	"order_observing": ["[c=#f5a524]INFO[/c] requests: sequential contract verified in Lab", "[c=#f5a524]TODO[/c] concurrent requests and customer rollout still pending"],
	"normal": [
		"[c=#3ddc84]200[/c] GET  /api/orders            38ms",
		"[c=#3ddc84]200[/c] POST /api/login             112ms",
		"[c=#3ddc84]200[/c] GET  /api/users/me          21ms",
		"[c=#3ddc84]201[/c] POST /api/orders            64ms",
		"[c=#3ddc84]200[/c] GET  /api/payments/status   45ms",
	],
	"profile_bug": [
		"[c=#3ddc84]200[/c] GET  /api/users/me          22ms   displayName=\"undefined Choi\"",
		"[c=#f5a524]WARN[/c] profile.render  displayName contains 'undefined' (user=1042)",
		"[c=#3ddc84]200[/c] GET  /api/orders            41ms",
		"[c=#f5a524]WARN[/c] profile.render  displayName contains 'null' (user=877)",
	],
	"auth_down": [
		"[c=#ff5c6c]504[/c] POST /api/login           30012ms  upstream=idp.nexora.dev  AUTH_TIMEOUT?",
		"[c=#ff5c6c]ERR[/c]  auth.login  request still pending after 30000ms (no timeout configured)",
		"[c=#ff5c6c]504[/c] POST /api/login           30008ms  upstream=idp.nexora.dev",
		"[c=#f5a524]WARN[/c] idp.nexora.dev  connection pool exhausted (64/64 waiting)",
		"[c=#3ddc84]200[/c] GET  /api/orders            44ms",
		"[c=#ff5c6c]ERR[/c]  gateway  login worker threads blocked: 61",
	],
	"payments": [
		"[c=#ff5c6c]ERR[/c]  payments.charge  amount=-8000 (coupon=PERCENT10) rejected by PG",
		"[c=#f5a524]WARN[/c] orders.applyCoupon  total=10000 coupon={percent,10} -> -90000",
		"[c=#3ddc84]200[/c] GET  /api/orders            39ms",
		"[c=#ff5c6c]ERR[/c]  payments.charge  amount=0 (coupon=AMOUNT5000) suspicious zero charge",
	],
}

var _cards: HBoxContainer
var _chart: Control
var _log: RichTextLabel
var _timer: Timer
var _series: Array = []
var _rng := RandomNumberGenerator.new()
var _reported_mode := ""


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var top := UITheme.vbox(10)
	add_child(UITheme.margin(top, 14))
	_cards = UITheme.hbox(10)
	top.add_child(_cards)
	var chart_panel := UITheme.panel(UITheme.BG2, 10, 12, Color(0, 0, 0, 0))
	var cv := UITheme.vbox(6)
	cv.add_child(UITheme.label(Game.L("에러율 (최근 60초)", "Error rate (last 60 s)"), 12, UITheme.MUTED))
	_chart = Control.new()
	_chart.custom_minimum_size.y = 110
	_chart.draw.connect(_draw_chart)
	cv.add_child(_chart)
	chart_panel.add_child(cv)
	top.add_child(chart_panel)
	top.add_child(UITheme.label(Game.L("로그 스트림", "Log stream"), 12, UITheme.MUTED))
	top.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", UITheme.font(true))
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_stylebox_override("normal", UITheme.box(Color("0a0c10"), 8, UITheme.LINE, 10))
	top.add_child(_log)
	for i in 60:
		_series.append(_rate())
	_timer = Timer.new()
	_timer.wait_time = 0.7
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind == "monitor":
			_render_cards())
	_render_cards()
	for i in 8:
		_tick()


func _mode() -> String:
	return String(Game.state["monitor"].get("mode", "normal"))


func _rate() -> float:
	match _mode():
		"auth_down":
			return _rng.randf_range(30, 45)
		"payments":
			return _rng.randf_range(6, 12)
		"profile_bug":
			return _rng.randf_range(2, 5)
	return _rng.randf_range(0.1, 0.6)


func _tick() -> void:
	_series.append(_rate())
	if _series.size() > 60:
		_series.pop_front()
	_chart.queue_redraw()
	var pool: Array = LOGS.get(_mode(), LOGS["normal"])
	var line: String = pool[_rng.randi() % pool.size()]
	var incident_line := _mode() != "normal"
	if _mode() != "normal" and _rng.randf() < 0.4:
		line = LOGS["normal"][_rng.randi() % LOGS["normal"].size()]
		incident_line = false
	line = line.replace("[c=", "[color=").replace("[/c]", "[/color]")
	var t := Time.get_time_dict_from_system()
	_log.append_text("[color=#6f7a8c]%02d:%02d:%02d[/color]  %s\n" % [t["hour"], t["minute"], t["second"], line])
	if incident_line and is_visible_in_tree() and _reported_mode != _mode():
		_reported_mode = _mode()
		Game.emit_event("monitor_viewed", {"mode": _mode()})


func _render_cards() -> void:
	UITheme.clear(_cards)
	var status: Dictionary = Game.state["monitor"]["status"]
	for s in SERVICES:
		var st := String(status.get(s[0], "ok"))
		var c := {"ok": UITheme.OK, "warn": UITheme.WARN, "down": UITheme.ERR}[st] as Color
		var card := UITheme.panel(Color(c, 0.08), 10, 12, Color(c, 0.4))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(4)
		v.add_child(UITheme.bold(s[1], 14))
		v.add_child(UITheme.label({"ok": Game.L("● 정상", "● Healthy"), "warn": Game.L("● 경고", "● Degraded"), "down": Game.L("● 장애", "● Down")}[st], 13, c))
		card.add_child(v)
		_cards.add_child(card)


func _draw_chart() -> void:
	var w := _chart.size.x
	var h := _chart.size.y
	for i in 5:
		var y := h * i / 4.0
		_chart.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.05))
	var max_v := 50.0
	var pts := PackedVector2Array()
	for i in _series.size():
		pts.append(Vector2(w * i / 59.0, h - clampf(_series[i] / max_v, 0, 1) * h))
	var c := UITheme.ERR if _mode() == "auth_down" else (UITheme.WARN if _mode() != "normal" else UITheme.OK)
	var fill := pts.duplicate()
	fill.append(Vector2(w, h))
	fill.append(Vector2(0, h))
	_chart.draw_colored_polygon(fill, Color(c, 0.12))
	_chart.draw_polyline(pts, c, 2.0, true)
	_chart.draw_string(UITheme.font(true), Vector2(w - 70, 14), "%.1f%%" % _series[-1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
