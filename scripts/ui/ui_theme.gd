extends RefCounted
## Shared fonts, theme and small UI helpers.

const UI_FONTS := ["Pretendard", "Malgun Gothic", "Segoe UI", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"]
const MONO_FONTS := ["D2Coding", "Cascadia Mono", "Consolas", "Menlo", "monospace"]

static var _cache := {}


static func font(mono := false, bold := false) -> Font:
	var key := "%s-%s" % [mono, bold]
	if not _cache.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(MONO_FONTS if mono else UI_FONTS)
		f.font_weight = 700 if bold else 400
		_cache[key] = f
	return _cache[key]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 14
	t.set_color("font_color", "Label", Color("d8dde6"))
	t.set_stylebox("panel", "TooltipPanel", box(Color("1e222b"), 6, Color("343a46"), 6))
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
	s.anti_aliasing = true
	return s


static func label(text: String, size := 14, color := Color("d8dde6"), mono := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if mono:
		l.add_theme_font_override("font", font(true))
	return l
