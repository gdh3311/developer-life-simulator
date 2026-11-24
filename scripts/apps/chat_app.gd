extends HSplitContainer
## TeamChat: #general + DMs with teammates. Some messages offer reply choices.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var desktop: Control
var _channel := "general"
var _list: VBoxContainer
var _header: VBoxContainer
var _msgs: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	split_offset = 210
	add_theme_constant_override("separation", 0)
	var left := UITheme.panel(UITheme.BG0, 0, 8, Color(0, 0, 0, 0))
	left.custom_minimum_size.x = 200
	_list = UITheme.vbox(2)
	left.add_child(_list)
	add_child(left)

	var right := UITheme.vbox(0)
	_header = UITheme.vbox(6)
	right.add_child(UITheme.margin(_header, 12))
	var line := ColorRect.new()
	line.color = UITheme.LINE
	line.custom_minimum_size.y = 1
	right.add_child(line)
	_msgs = UITheme.vbox(14)
	_scroll = UITheme.scroll(UITheme.margin(_msgs, 14))
	right.add_child(_scroll)
	add_child(right)

	Game.chat_added.connect(func(m: Dictionary) -> void:
		if m["channel"] == _channel:
			Game.mark_read(_channel)
			if m["from"] not in ["me", "system"]:
				_show_typing(int(m["id"]))
				return
		_render())
	Game.chat_updated.connect(_render)
	Game.relation_changed.connect(func(_n: String, _k: String, _d: int) -> void: _render_header())
	# Open the channel with unread messages first.
	for ch in Game.state["unread"]:
		if ch != "connectly" and int(Game.state["unread"][ch]) > 0:
			_channel = ch
			break
	Game.mark_read(_channel)
	_render()


func _channels() -> Array:
	var result := [["general", "# general"]]
	var people := ["alex", "daniel", "mina", "sophie", "ai"]
	if Game.chapter() >= 2:
		people.insert(4, "yuri")
	if Game.chapter() >= 3:
		people.insert(5, "taeseok")
	for npc in people:
		result.append(["dm:" + npc, Game.npc_name(npc)])
	return result


func open_channel(id: String) -> void:
	if _channels().any(func(channel: Array) -> bool: return channel[0] == id):
		_channel = id
		Game.mark_read(id)
		_render()


func _render() -> void:
	UITheme.clear(_list)
	_list.add_child(UITheme.label(Game.L("  채널", "  Channels"), 11, UITheme.MUTED))
	for ch in _channels():
		var id: String = ch[0]
		var b := Button.new()
		b.flat = id != _channel
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT.darkened(0.55) if id == _channel else Color(0, 0, 0, 0), 6, Color(0, 0, 0, 0), 6))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.05), 6, Color(0, 0, 0, 0), 6))
		var unread := int(Game.state["unread"].get(id, 0))
		b.text = "%s%s" % [ch[1], ("   (%d)" % unread) if unread > 0 and id != _channel else ""]
		b.add_theme_color_override("font_color", UITheme.TEXT if unread > 0 or id == _channel else UITheme.TEXT2)
		b.pressed.connect(open_channel.bind(id))
		_list.add_child(b)
		if id == "general":
			_list.add_child(UITheme.label(Game.L("  다이렉트 메시지", "  Direct messages"), 11, UITheme.MUTED))
	_render_header()
	UITheme.clear(_msgs)
	var any := false
	for m in Game.state["chat"]:
		if m["channel"] != _channel:
			continue
		any = true
		if int(m["id"]) in _typing:
			_msgs.add_child(_typing_row(m["from"]))
			continue
		_msgs.add_child(_message(m))
	if not any:
		_msgs.add_child(UITheme.label(Game.L("아직 메시지가 없습니다.", "No messages yet."), 13, UITheme.MUTED))
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _render_header() -> void:
	UITheme.clear(_header)
	if _channel == "general":
		_header.add_child(UITheme.bold("# general", 16))
		_header.add_child(UITheme.label(Game.L("NEXORA 개발팀 전체 채널", "NEXORA dev team channel"), 12, UITheme.MUTED))
		return
	var npc := _channel.substr(3)
	var row := UITheme.hbox(10)
	row.add_child(UITheme.avatar(npc, 36))
	var v := UITheme.vbox(0)
	v.add_child(UITheme.bold(Game.npc_name(npc), 15))
	v.add_child(UITheme.label(Game.npc_role(npc), 12, UITheme.MUTED))
	row.add_child(v)
	row.add_child(UITheme.spacer())
	if Game.state["rel"].has(npc):
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 2)
		for key in Game.REL_KEYS:
			grid.add_child(UITheme.label(Game.rel_label(key), 10, UITheme.MUTED))
			grid.add_child(UITheme.bar(Game.rel(npc, key), Game.npc_color(npc), 60))
		row.add_child(grid)
	_header.add_child(row)


func _message(m: Dictionary) -> Control:
	var mine: bool = m["from"] == "me"
	var row := UITheme.hbox(10)
	if mine:
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(UITheme.spacer())
	else:
		row.add_child(UITheme.avatar(m["from"], 32))
	var col := UITheme.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not mine else Control.SIZE_SHRINK_END
	if not mine:
		var head := UITheme.hbox(8)
		head.add_child(UITheme.bold(Game.npc_name(m["from"]), 13, Game.npc_color(m["from"]).lightened(0.3)))
		head.add_child(UITheme.label(m["time"], 11, UITheme.MUTED))
		col.add_child(head)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UITheme.box(UITheme.ACCENT.darkened(0.35) if mine else UITheme.BG3, 10, Color(0, 0, 0, 0), 10))
	var text := UITheme.label(Game.tx(m["text"]), 14, UITheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 120 if mine else 0
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_child(text)
	if mine:
		bubble.custom_minimum_size.x = mini(Game.tx(m["text"]).length() * 9 + 30, 420)
	col.add_child(bubble)
	var link = m.get("link", {})
	if desktop != null and link is Dictionary and link.get("app") in ["browser", "pork"]:
		var jump := UITheme.button(Game.tx(link.get("label", "")) + "  ↗")
		jump.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		jump.pressed.connect(desktop.open_resource.bind(link["app"], String(link.get("target", ""))))
		col.add_child(jump)
	var choices: Array = m["choices"]
	if not choices.is_empty() and m["answered"] == "":
		var opts := UITheme.vbox(6)
		opts.add_child(UITheme.choice_header())
		for c in choices:
			var b := UITheme.choice_button(Game.tx(c["label"]))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var mid := int(m["id"])
			var cid: String = c["id"]
			b.pressed.connect(func() -> void: Game.answer(mid, cid))
			opts.add_child(b)
		col.add_child(opts)
	row.add_child(col)
	return row


# --- "is typing..." --------------------------------------------------------------

var _typing: Array = []


## Shows a typing indicator before revealing a teammate's new message (longer text, longer typing).
func _show_typing(id: int) -> void:
	_typing.append(id)
	_render()
	var text := ""
	for m in Game.state["chat"]:
		if int(m["id"]) == id:
			text = Game.tx(m["text"])
	await get_tree().create_timer(clampf(0.5 + text.length() * 0.012, 0.6, 1.8)).timeout
	_typing.erase(id)
	if is_inside_tree():
		_render()


func _typing_row(from: String) -> Control:
	var row := UITheme.hbox(10)
	row.add_child(UITheme.avatar(from, 32))
	var bubble := UITheme.panel(UITheme.BG3, 10, 10, Color(0, 0, 0, 0))
	var dots := UITheme.label("•  •  •", 14, UITheme.TEXT2)
	bubble.add_child(dots)
	var col := UITheme.vbox(4)
	col.add_child(UITheme.label(Game.L("%s 님이 입력 중...", "%s is typing...") % Game.npc_name(from), 11, UITheme.MUTED))
	col.add_child(bubble)
	row.add_child(col)
	var t := dots.create_tween().set_loops()
	t.tween_property(dots, "modulate:a", 0.3, 0.35)
	t.tween_property(dots, "modulate:a", 1.0, 0.35)
	return row
