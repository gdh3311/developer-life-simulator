extends ScrollContainer
## Request Lab tab: compose the customer reply from four slots and preview it.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Reply := preload("res://scripts/story/missions/c02_08_reply.gd")

var _root: VBoxContainer
var _picks := {}
var _preview: Label
var _send: Button


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root = UITheme.vbox(10)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UITheme.margin(_root, 14))
	get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Story.objectives_changed.connect(_render)
	_render()


func _mission():
	return Story.mission("c02_08")


func _render() -> void:
	UITheme.clear(_root)
	var m = _mission()
	_root.add_child(UITheme.bold(Game.L("달빛상점 답장 초안", "Reply to Moonlight"), 17))
	_root.add_child(UITheme.wrap(Game.L("고객의 말로, 확인한 만큼만. 내부 용어와 과한 약속은 빼고, 고객이 할 일과 남은 조치를 적어요.",
		"In the customer's words, no more than we verified. Skip jargon and big promises; say what they should do and what's still in progress."), 12, UITheme.TEXT2))
	var state: Dictionary = Game.state["flags"].get("c02_reply", {})
	if state.get("sent", false):
		_root.add_child(UITheme.label(Game.L("보냄 · Yuri가 고객에게 전달했습니다.", "Sent · Yuri forwarded it to the customer."), 13, UITheme.OK))
		var saved: Dictionary = state.get("picks", {})
		_root.add_child(_letter(saved))
		return
	if m == null or Story.status("c02_08") != "active":
		_root.add_child(UITheme.label(Game.L("답장 요청이 오면 여기서 작성합니다.", "Write the reply here when it's requested."), 13, UITheme.MUTED))
		return
	for slot in Reply.SLOTS:
		var info: Dictionary = Reply.SLOTS[slot]
		_root.add_child(UITheme.label(Game.tx(info["label"]), 12, UITheme.MUTED))
		var group := ButtonGroup.new()
		for option in info["options"]:
			var b := CheckBox.new()
			b.button_group = group
			b.text = Game.tx(option[1])
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 560
			b.focus_mode = Control.FOCUS_NONE
			b.button_pressed = _picks.get(slot, "") == option[0]
			var oid: String = option[0]
			var sid: String = slot
			b.toggled.connect(func(on: bool) -> void:
				if on:
					_picks[sid] = oid
					_update_preview())
			_root.add_child(b)
	_root.add_child(UITheme.label(Game.L("미리 보기", "Preview"), 12, UITheme.MUTED))
	var card := UITheme.panel(UITheme.BG3, 8, 12, Color(1, 1, 1, 0.05))
	_preview = UITheme.wrap("", 13, UITheme.TEXT)
	card.add_child(_preview)
	_root.add_child(card)
	_send = UITheme.button(Game.L("Yuri에게 보내기", "Send to Yuri"), "primary")
	_send.custom_minimum_size.y = 38
	_send.pressed.connect(func() -> void:
		var notes: Array = m.submit(_picks.duplicate())
		if notes.is_empty():
			_render())
	_root.add_child(_send)
	_update_preview()


func _sentence(slot: String, option_id: String) -> String:
	for option in Reply.SLOTS[slot]["options"]:
		if option[0] == option_id and option_id != "omit":
			return Game.tx(option[1])
	return ""


func _letter_text(picks: Dictionary) -> String:
	var lines: Array = [Game.L("윤서진 대표님, 안녕하세요. NEXORA 고객 지원팀입니다.", "Hello Seojin, this is NEXORA customer support.")]
	for slot in Reply.SLOTS:
		var s := _sentence(slot, String(picks.get(slot, "")))
		if s != "":
			lines.append(s)
	lines.append(Game.L("감사합니다.\nYuri 드림", "Thank you,\nYuri"))
	return "\n\n".join(lines)


func _letter(picks: Dictionary) -> Control:
	var card := UITheme.panel(UITheme.BG3, 8, 12, Color(1, 1, 1, 0.05))
	card.add_child(UITheme.wrap(_letter_text(picks), 13, UITheme.TEXT))
	return card


func _update_preview() -> void:
	if _preview != null:
		_preview.text = _letter_text(_picks)
	if _send != null:
		_send.disabled = _picks.size() < Reply.SLOTS.size()
