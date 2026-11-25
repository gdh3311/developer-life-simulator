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
	for spec in list:
		_root.add_child(_form(spec))
	var past := archive()
	if not past.is_empty():
		_root.add_child(UITheme.label(Game.L("내 문서함  ·  %d", "My documents  ·  %d") % past.size(), 12, UITheme.MUTED))
		for doc in past:
			_root.add_child(_archived(doc))


## Every document you submitted in finished tasks, newest first, with comments from others.
static func archive() -> Array:
	var docs: Array = []
	var comments: Dictionary = Game.state["flags"].get("doc_comments", {})
	for m in Story.missions():
		if Story.status(m.id) != "done" or m.forms_def.is_empty():
			continue
		var saved: Dictionary = Game.state["story"].get(m.id, {}).get("data", {}).get("forms", {})
		for form_id in saved:
			if not m.forms_def.has(form_id):
				continue
			var spec: Dictionary = m.forms_def[form_id]
			if m.has_method("manual") and m.manual():
				# Documents keep the title they were written under (e.g. the manual pilot).
				spec = spec.duplicate(true)
				spec["title"] = {"ko": "수동 대조 시범 판매자", "en": "Manual reconciliation pilot seller"}
			if m.has_method("_records") and form_id == "review":
				spec = spec.duplicate(true)
				spec["slots"][0]["options"] = m._records().map(func(x: Dictionary) -> Dictionary: return {"id": x["id"], "text": x["text"]})
			docs.append({"key": m.id + ":" + form_id, "title": spec["title"], "spec": spec, "picks": saved[form_id],
				"task": m.issue, "day": m.day, "comments": comments.get(m.id + ":" + form_id, [])})
	for a in Story.arcs.all():
		for form_id in a.data().get("forms", {}):
			var spec: Dictionary = a.forms_def.get(form_id, {})
			if spec.is_empty() and a.has_method("_migration_form") and form_id == "migration":
				spec = a._migration_form()
			if spec.is_empty():
				continue
			docs.append({"key": a.id + ":" + form_id, "title": spec["title"], "spec": spec, "picks": a.data()["forms"][form_id],
				"task": Game.tx(a.title), "day": 99, "comments": comments.get(a.id + ":" + form_id, [])})
	docs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["day"]) > int(y["day"]))
	return docs


func _archived(doc: Dictionary) -> Control:
	var card := UITheme.panel(UITheme.BG1, 10, 12, Color(1, 1, 1, 0.04))
	var v := UITheme.vbox(6)
	card.add_child(v)
	var head := UITheme.hbox(8)
	var title := UITheme.bold(Game.tx(doc["title"]), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.label(String(doc["task"]), 11, UITheme.MUTED))
	var comments: Array = doc["comments"]
	if not comments.is_empty():
		head.add_child(UITheme.chip(Game.L("댓글 %d", "%d comments") % comments.size(), UITheme.ACCENT))
	var toggle := UITheme.button(Game.L("열기", "Open"))
	head.add_child(toggle)
	v.add_child(head)
	var detail := UITheme.vbox(6)
	detail.visible = false
	v.add_child(detail)
	toggle.pressed.connect(func() -> void:
		detail.visible = not detail.visible
		toggle.text = Game.L("닫기", "Close") if detail.visible else Game.L("열기", "Open"))
	var spec: Dictionary = doc["spec"]
	for slot in spec["slots"]:
		var chosen := FormRules.picked(doc["picks"], slot["id"])
		if chosen.is_empty():
			continue
		detail.add_child(UITheme.label(Game.tx(slot["label"]), 11, UITheme.MUTED))
		for id in chosen:
			detail.add_child(UITheme.wrap("· " + Game.tx(FormRules.option(spec, slot["id"], id).get("text", {})), 12, UITheme.TEXT))
	for c in comments:
		var row := UITheme.hbox(8)
		row.add_child(UITheme.avatar(String(c["from"]), 22))
		var text := UITheme.wrap("%s  ·  %s" % [Game.npc_name(String(c["from"])), Game.tx(c["text"])], 12, UITheme.TEXT2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		detail.add_child(row)
	return card


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
		# Inline slots (classification grids) lay their options out side by side.
		var holder: Container = v
		if slot.get("inline", false):
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			v.add_child(flow)
			holder = flow
		for o in slot["options"]:
			var b := CheckBox.new()
			if group != null:
				b.button_group = group
			var text := Game.tx(o["text"])
			if o.has("cost"):
				text += Game.L("  · %d일", "  · %d d") % int(o["cost"])
			b.text = text
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 0
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if slot.get("inline", false) else Control.SIZE_EXPAND_FILL
			if slot.get("inline", false):
				b.autowrap_mode = TextServer.AUTOWRAP_OFF
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
			holder.add_child(b)
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
