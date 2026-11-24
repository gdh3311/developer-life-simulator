extends ScrollContainer
## Docs: structured documents the current task or a storyline asks for (scope, release note,
## ownership, review records, audit samples). Options are picked, previewed and submitted;
## the owner (mission or arc) explains what to fix or accepts it.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const FormRules := preload("res://scripts/story/form_rules.gd")

var _root: VBoxContainer
var _picks := {}      # form key -> { slot: id | [ids] }
var _notes := {}      # form key -> Array of {ko,en}


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root = UITheme.vbox(12)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UITheme.margin(_root, 16))
	get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Story.objectives_changed.connect(_render)
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind in ["arc_stage", "arc_status", "form_submitted"]:
			_render())
	_render()


static func forms() -> Array:
	var result: Array = []
	if Story.active != null:
		result.append_array(Story.active.open_forms())
	result.append_array(Story.arcs.open_forms())
	return result


static func owner_of(spec: Dictionary):
	return Story.arcs.arc(spec["arc"]) if spec.has("arc") else Story.active


static func submit(spec: Dictionary, picks: Dictionary) -> Array:
	var owner = owner_of(spec)
	return owner.submit_form(spec["id"], picks) if owner != null else []


func _key(spec: Dictionary) -> String:
	return String(spec.get("arc", "task")) + ":" + String(spec["id"])


func _render() -> void:
	UITheme.clear(_root)
	var list := forms()
	if list.is_empty():
		_root.add_child(UITheme.bold("Docs", 17))
		_root.add_child(UITheme.label(Game.L("지금 작성할 문서가 없습니다. 업무나 동료가 문서를 요청하면 여기에 나타납니다.",
			"No documents to write right now. They appear here when a task or a teammate asks for one."), 13, UITheme.MUTED))
		return
	for spec in list:
		_root.add_child(_form(spec))


func _form(spec: Dictionary) -> Control:
	var key := _key(spec)
	var card := UITheme.panel(UITheme.BG2, 10, 14, Color(1, 1, 1, 0.05))
	var v := UITheme.vbox(8)
	card.add_child(v)
	var head := UITheme.hbox(8)
	head.add_child(UITheme.bold(Game.tx(spec["title"]), 16))
	if spec.has("arc"):
		head.add_child(UITheme.label(Game.L("· 스토리라인", "· storyline"), 11, UITheme.ACCENT))
	v.add_child(head)
	v.add_child(UITheme.wrap(Game.tx(spec.get("intro", {})), 12, UITheme.TEXT2))
	if spec["done"]:
		v.add_child(UITheme.label(Game.L("제출됨", "Submitted"), 12, UITheme.OK))
		for slot in spec["slots"]:
			var chosen := FormRules.picked(spec["picks"], slot["id"])
			var texts: Array = chosen.map(func(id: String) -> String: return Game.tx(FormRules.option(spec, slot["id"], id).get("text", {})))
			v.add_child(UITheme.label(Game.tx(slot["label"]), 11, UITheme.MUTED))
			v.add_child(UITheme.wrap("\n".join(texts.map(func(x: String) -> String: return "· " + x)), 12, UITheme.TEXT))
		return card
	if not _picks.has(key):
		_picks[key] = {}
	var picks: Dictionary = _picks[key]
	for slot in spec["slots"]:
		var capacity_label: Label = null
		var sid: String = slot["id"]
		var label_text := Game.tx(slot["label"])
		if slot.get("multi", false) and slot.has("max"):
			label_text += Game.L("  (최대 %d)", "  (up to %d)") % int(slot["max"])
		v.add_child(UITheme.label(label_text, 12, UITheme.MUTED))
		if slot.has("capacity"):
			capacity_label = UITheme.label("", 12, UITheme.TEXT2)
			v.add_child(capacity_label)
		var group: ButtonGroup = null if slot.get("multi", false) else ButtonGroup.new()
		for o in slot["options"]:
			var b := CheckBox.new()
			if group != null:
				b.button_group = group
			var text := Game.tx(o["text"])
			if o.has("cost"):
				text += Game.L("  · %d일", "  · %d d") % int(o["cost"])
			b.text = text
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 560
			b.focus_mode = Control.FOCUS_NONE
			b.button_pressed = FormRules.picked(picks, sid).has(o["id"])
			var oid: String = o["id"]
			var multi: bool = slot.get("multi", false)
			var cap := capacity_label
			var slot_ref: Dictionary = slot
			b.toggled.connect(func(on: bool) -> void:
				if multi:
					var arr: Array = FormRules.picked(picks, sid).duplicate()
					if on and not arr.has(oid):
						arr.append(oid)
					elif not on:
						arr.erase(oid)
					picks[sid] = arr
				elif on:
					picks[sid] = oid
				if cap != null:
					_update_capacity(cap, spec, slot_ref, picks))
			v.add_child(b)
		if capacity_label != null:
			_update_capacity(capacity_label, spec, slot, picks)
	var notes: Array = _notes.get(key, [])
	if not notes.is_empty():
		var box := UITheme.panel(Color(1, 0.36, 0.42, 0.08), 8, 10, Color(1, 0.36, 0.42, 0.3))
		var nv := UITheme.vbox(4)
		for n in notes:
			nv.add_child(UITheme.wrap("• " + Game.tx(n), 12, UITheme.TEXT))
		box.add_child(nv)
		v.add_child(box)
	var send := UITheme.button(Game.tx(spec.get("submit", {"ko": "제출", "en": "Submit"})), "primary")
	send.custom_minimum_size.y = 36
	send.pressed.connect(func() -> void:
		var result := submit(spec, picks.duplicate(true))
		_notes[key] = result
		if result.is_empty():
			Sfx.play("send")
		_render())
	v.add_child(send)
	return card


func _update_capacity(label: Label, spec: Dictionary, slot: Dictionary, picks: Dictionary) -> void:
	var used := FormRules.cost(spec, slot["id"], picks)
	var cap := int(slot["capacity"])
	label.text = Game.L("사용 %d / %d일", "Using %d / %d days") % [used, cap]
	label.add_theme_color_override("font_color", UITheme.ERR if used > cap else UITheme.TEXT2)
