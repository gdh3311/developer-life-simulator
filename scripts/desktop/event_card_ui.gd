extends Control
## Presents a pending event card: an incoming phone call (answer/decline, then the conversation),
## a teammate standing at the desk, or an OS popup (modal). Choices go to Story.events.resolve.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var _card_id := ""
var _panel: PanelContainer
var _dim: ColorRect
var _ringing := false
var _ring_time := 0.0


func _ready() -> void:
	# Already in the tree here: plain set_anchors_preset would keep the current (empty) rect.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind in ["event_card", "event_resolved"]:
			refresh())
	refresh()


func card_id() -> String:
	return _card_id


func refresh() -> void:
	var c: Dictionary = Story.events.pending()
	var id := String(Game.state.get("events", {}).get("pending", {}).get("id", "")) if not c.is_empty() else ""
	if id == _card_id:
		return
	_clear()
	_card_id = id
	if id == "":
		return
	match String(c.get("format", "")):
		"call":
			_show_call(c, false)
		"desk_visit":
			_show_visit(c)
		"popup":
			_show_popup(c)


func _clear() -> void:
	_ringing = false
	for child in get_children():
		child.queue_free()
	_panel = null
	_dim = null


func _process(delta: float) -> void:
	if _ringing and _panel != null:
		_ring_time += delta
		_panel.rotation = sin(_ring_time * 40.0) * 0.012 * (1.0 if fmod(_ring_time, 1.4) < 0.5 else 0.0)
		if fmod(_ring_time, 1.4) < delta:
			Sfx.play("notify", 1.2, -10.0)


func _corner_panel(width: float) -> VBoxContainer:
	_panel = UITheme.panel(UITheme.BG2, 14, 14, Color(1, 1, 1, 0.08))
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -width - 16.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = -100.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var v := UITheme.vbox(8)
	_panel.add_child(v)
	return v


func _header(v: VBoxContainer, npc: String, subtitle: String) -> void:
	var h := UITheme.hbox(10)
	h.add_child(UITheme.avatar(npc, 38))
	var names := UITheme.vbox(0)
	names.add_child(UITheme.bold(Game.npc_name(npc), 15))
	names.add_child(UITheme.label(subtitle, 11, UITheme.MUTED))
	h.add_child(names)
	v.add_child(h)


func _choices(v: VBoxContainer, c: Dictionary) -> void:
	for ch in c["choices"]:
		if c.get("format", "") == "call" and ch["id"] == c.get("decline", "") and String(ch["label"].get("ko", "")).begins_with("("):
			continue
		var b := UITheme.choice_button(Game.tx(ch["label"]))
		var cid: String = ch["id"]
		b.pressed.connect(func() -> void: choose(cid))
		v.add_child(b)


## Pick a choice (also used by tests).
func choose(choice_id: String) -> void:
	var id := _card_id
	if id == "":
		return
	Sfx.play("click")
	Story.events.resolve(id, choice_id)


func _show_call(c: Dictionary, answered: bool) -> void:
	var v := _corner_panel(360)
	if not answered:
		_header(v, c["from"], Game.L("전화 수신 중…", "Incoming call…"))
		var row := UITheme.hbox(8)
		var decline := UITheme.button(Game.L("거절", "Decline"))
		decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decline.pressed.connect(func() -> void: choose(String(c.get("decline", c["choices"][-1]["id"]))))
		var answer := UITheme.button(Game.L("받기", "Answer"), "ok")
		answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer.pressed.connect(answer_call)
		row.add_child(decline)
		row.add_child(answer)
		v.add_child(row)
		_ringing = true
		_ring_time = 0.0
		return
	_header(v, c["from"], Game.L("통화 중", "On a call"))
	v.add_child(UITheme.wrap(Game.tx(c["text"]), 13, UITheme.TEXT))
	_choices(v, c)


func answer_call() -> void:
	var c: Dictionary = Story.events.pending()
	if c.is_empty() or c.get("format", "") != "call":
		return
	var id := _card_id
	_clear()
	_card_id = id
	_show_call(c, true)


func _show_visit(c: Dictionary) -> void:
	var v := _corner_panel(380)
	_header(v, c["from"], Game.L("자리로 찾아왔다", "Came over to your desk"))
	v.add_child(UITheme.wrap(Game.tx(c["text"]), 13, UITheme.TEXT))
	_choices(v, c)


func _show_popup(c: Dictionary) -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = UITheme.panel(UITheme.BG2, 14, 18, Color(1, 1, 1, 0.1))
	_panel.custom_minimum_size.x = 460
	center.add_child(_panel)
	var v := UITheme.vbox(10)
	_panel.add_child(v)
	var h := UITheme.hbox(8)
	var icon := Icon.new()
	icon.icon = "bell"
	icon.custom_minimum_size = Vector2(18, 18)
	icon.color = UITheme.WARN
	h.add_child(icon)
	h.add_child(UITheme.bold(Game.tx(c.get("title", {"ko": "알림", "en": "Notice"})), 16))
	v.add_child(h)
	v.add_child(UITheme.wrap(Game.tx(c["text"]), 13, UITheme.TEXT2))
	_choices(v, c)
	Sfx.play("notify")
