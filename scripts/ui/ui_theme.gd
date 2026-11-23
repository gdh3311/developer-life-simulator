extends RefCounted
## Shared palette, fonts, theme and small UI building blocks.

const UI_FONTS := ["Pretendard", "Malgun Gothic", "Segoe UI", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"]
const MONO_FONTS := ["D2Coding", "Cascadia Mono", "Consolas", "Menlo", "monospace"]

const BG0 := Color("0d1016")
const BG1 := Color("12161e")
const BG2 := Color("181d27")
const BG3 := Color("212735")
const LINE := Color("2a3140")
const TEXT := Color("e6e9ef")
const TEXT2 := Color("aab3c2")
const MUTED := Color("6f7a8c")
const ACCENT := Color("5b8cff")
const OK := Color("3ddc84")
const WARN := Color("f5a524")
const ERR := Color("ff5c6c")

static var _cache := {}


static func font(mono := false, bold := false) -> Font:
	var key := "%s-%s" % [mono, bold]
	if not _cache.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(MONO_FONTS if mono else UI_FONTS)
		f.font_weight = 700 if bold else 400
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_cache[key] = f
	return _cache[key]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(BG3, 6, LINE, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	# Buttons
	t.set_stylebox("normal", "Button", box(BG3, 7, LINE, 7))
	t.set_stylebox("hover", "Button", box(BG3.lightened(0.08), 7, LINE.lightened(0.2), 7))
	t.set_stylebox("pressed", "Button", box(BG2, 7, LINE, 7))
	t.set_stylebox("disabled", "Button", box(BG2, 7, BG3, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	# Inputs
	t.set_stylebox("normal", "LineEdit", box(BG1, 6, LINE, 8))
	t.set_stylebox("focus", "LineEdit", box(BG1, 6, ACCENT, 8))
	t.set_stylebox("normal", "TextEdit", box(BG1, 6, LINE, 8))
	t.set_stylebox("focus", "TextEdit", box(BG1, 6, ACCENT, 8))
	t.set_stylebox("normal", "OptionButton", box(BG3, 6, LINE, 7))
	t.set_stylebox("hover", "OptionButton", box(BG3.lightened(0.06), 6, LINE, 7))
	t.set_stylebox("panel", "PopupMenu", box(BG2, 6, LINE, 6))
	# Scrollbars
	var grab := box(Color(1, 1, 1, 0.14), 4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.24), 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Color(1, 1, 1, 0.3), 4))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("scroll", "HScrollBar", box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 2))
	# Tree / ItemList / tabs
	t.set_stylebox("panel", "Tree", box(BG1, 0, Color(0, 0, 0, 0), 6))
	t.set_stylebox("selected", "Tree", box(ACCENT.darkened(0.55), 4))
	t.set_stylebox("selected_focus", "Tree", box(ACCENT.darkened(0.5), 4))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", TEXT2)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_stylebox("tab_selected", "TabContainer", box(BG2, 0, Color(0, 0, 0, 0), 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(BG1, 0, Color(0, 0, 0, 0), 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(BG2.lightened(0.03), 0, Color(0, 0, 0, 0), 8))
	t.set_stylebox("panel", "TabContainer", box(BG2, 0))
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_stylebox("split_bar_background", "HSplitContainer", box(BG0, 0))
	return t


static func box(bg: Color, radius := 8, border := Color(0, 0, 0, 0), pad := 0, border_width := 1, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.set_content_margin_all(pad)
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_offset = Vector2(0, shadow / 4.0)
	s.anti_aliasing = true
	s.corner_detail = 10
	return s


static func label(text: String, size := 14, color := TEXT, mono := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if mono:
		l.add_theme_font_override("font", font(true))
	return l


static func bold(text: String, size := 14, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font(false, true))
	return l


static func wrap(text: String, size := 14, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(color, 0.16), 10, Color(color, 0.45), 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 11, color.lightened(0.25)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func button(text: String, kind := "default") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col: Color = {"primary": ACCENT, "ok": OK.darkened(0.25), "danger": ERR.darkened(0.2)}.get(kind, Color(0, 0, 0, 0))
	if col.a > 0.0:
		b.add_theme_stylebox_override("normal", box(col.darkened(0.15), 7, Color(0, 0, 0, 0), 7))
		b.add_theme_stylebox_override("hover", box(col, 7, Color(0, 0, 0, 0), 7))
		b.add_theme_stylebox_override("pressed", box(col.darkened(0.3), 7, Color(0, 0, 0, 0), 7))
		b.add_theme_stylebox_override("disabled", box(BG3, 7, Color(0, 0, 0, 0), 7))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_font_override("font", font(false, true))
	return b


## A horizontal bar for a 0..100 value.
static func bar(value: float, color: Color, width := 120.0) -> Control:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(width, 6)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_theme_stylebox_override("panel", box(Color(1, 1, 1, 0.07), 3))
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", box(color, 3))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(value / 100.0, 0.02, 1.0)
	back.add_child(fill)
	return back


static func avatar(npc: String, size := 34.0) -> Control:
	var p := PanelContainer.new()
	var c: Color = Game.npc_color(npc) if npc != "me" else ACCENT
	var sb := box(c.darkened(0.35), int(size / 2.0), c.lightened(0.1), 0, 2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var initial := Game.pname().left(1).to_upper() if npc == "me" else ("AI" if npc == "ai" else Game.npc_name(npc).left(1))
	var l := bold(initial, int(size * 0.42), Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func margin(child: Control, m := 12) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func panel(bg := BG2, radius := 10, pad := 12, border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, pad))
	return p


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
