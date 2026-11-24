extends Control
## Scalable control glyphs and artwork for the Relay brand mark.

const Art := preload("res://scripts/ui/illustrations.gd")

var icon := ""
var color := Color.WHITE
var stroke := 2.2


static func make(name: String, col: Color, px := 24.0) -> Control:
	var i = load("res://scripts/ui/icon.gd").new()
	i.icon = name
	i.color = col
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name == "relay":
		i.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return i


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	return o + Vector2(x, y) * s


func _line(pts: Array, w := -1.0) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p[0], p[1]))
	draw_polyline(arr, color, (stroke if w < 0 else w) * minf(size.x, size.y) / 24.0, true)


func _circle(x: float, y: float, r: float, filled := true) -> void:
	var s := minf(size.x, size.y)
	if filled:
		draw_circle(_p(x, y), r * s, color, true, -1.0, true)
	else:
		draw_arc(_p(x, y), r * s, 0, TAU, 32, color, stroke * s / 24.0, true)


func _rect(x: float, y: float, w: float, h: float, filled := false) -> void:
	var s := minf(size.x, size.y)
	var r := Rect2(_p(x, y), Vector2(w, h) * s)
	if filled:
		draw_rect(r, color)
	else:
		draw_rect(r, color, false, stroke * s / 24.0, true)


func _draw() -> void:
	match icon:
		"code":
			_line([[0.32, 0.28], [0.12, 0.5], [0.32, 0.72]])
			_line([[0.68, 0.28], [0.88, 0.5], [0.68, 0.72]])
			_line([[0.56, 0.2], [0.44, 0.8]])
		"terminal":
			_rect(0.08, 0.16, 0.84, 0.68)
			_line([[0.24, 0.38], [0.38, 0.5], [0.24, 0.62]])
			_line([[0.46, 0.64], [0.7, 0.64]])
		"pr":
			_circle(0.28, 0.22, 0.08, false)
			_circle(0.28, 0.78, 0.08, false)
			_circle(0.72, 0.78, 0.08, false)
			_line([[0.28, 0.3], [0.28, 0.7]])
			_line([[0.72, 0.7], [0.72, 0.38], [0.6, 0.26], [0.46, 0.26]])
			_line([[0.54, 0.18], [0.46, 0.26], [0.54, 0.34]])
		"pork":
			_line([[0.5, 0.07], [0.93, 0.5], [0.5, 0.93], [0.07, 0.5], [0.5, 0.07]])
			_line([[0.5, 0.29], [0.5, 0.7]])
			_line([[0.5, 0.44], [0.65, 0.55], [0.65, 0.65]])
			_circle(0.5, 0.28, 0.065)
			_circle(0.5, 0.71, 0.065)
			_circle(0.65, 0.65, 0.06)
		"home":
			_line([[0.12, 0.48], [0.5, 0.16], [0.88, 0.48]])
			_line([[0.23, 0.42], [0.23, 0.82], [0.77, 0.82], [0.77, 0.42]])
			_line([[0.43, 0.82], [0.43, 0.62], [0.57, 0.62], [0.57, 0.82]])
		"chat":
			_line([[0.14, 0.2], [0.86, 0.2], [0.86, 0.66], [0.46, 0.66], [0.26, 0.84], [0.28, 0.66], [0.14, 0.66], [0.14, 0.2]])
			_circle(0.34, 0.43, 0.04)
			_circle(0.5, 0.43, 0.04)
			_circle(0.66, 0.43, 0.04)
		"doc":
			_line([[0.22, 0.1], [0.62, 0.1], [0.8, 0.28], [0.8, 0.9], [0.22, 0.9], [0.22, 0.1]])
			_line([[0.62, 0.1], [0.62, 0.28], [0.8, 0.28]])
			_line([[0.34, 0.48], [0.68, 0.48]])
			_line([[0.34, 0.62], [0.68, 0.62]])
			_line([[0.34, 0.76], [0.56, 0.76]])
		"tasks":
			_rect(0.1, 0.16, 0.22, 0.68)
			_rect(0.39, 0.16, 0.22, 0.46)
			_rect(0.68, 0.16, 0.22, 0.3)
		"wiki":
			_line([[0.5, 0.26], [0.5, 0.82]])
			_line([[0.5, 0.26], [0.32, 0.18], [0.1, 0.2], [0.1, 0.76], [0.32, 0.74], [0.5, 0.82]])
			_line([[0.5, 0.26], [0.68, 0.18], [0.9, 0.2], [0.9, 0.76], [0.68, 0.74], [0.5, 0.82]])
		"monitor":
			_rect(0.08, 0.14, 0.84, 0.72)
			_line([[0.16, 0.66], [0.34, 0.5], [0.48, 0.6], [0.64, 0.32], [0.84, 0.44]])
		"ai":
			var c := Vector2(0.44, 0.52)
			var pts := PackedVector2Array()
			for i in 8:
				var r := 0.36 if i % 2 == 0 else 0.1
				var a := TAU * i / 8.0 - PI / 2
				pts.append(_p(c.x + cos(a) * r, c.y + sin(a) * r))
			draw_colored_polygon(pts, color)
			_circle(0.8, 0.2, 0.06)
		"dashboard":
			var s := minf(size.x, size.y)
			draw_arc(_p(0.5, 0.62), 0.38 * s, PI, TAU, 32, color, stroke * s / 24.0, true)
			_line([[0.5, 0.62], [0.68, 0.38]])
			_circle(0.5, 0.62, 0.06)
		"check":
			_line([[0.2, 0.52], [0.42, 0.72], [0.8, 0.28]], 3.0)
		"x":
			_line([[0.26, 0.26], [0.74, 0.74]], 3.0)
			_line([[0.74, 0.26], [0.26, 0.74]], 3.0)
		"dot":
			_circle(0.5, 0.5, 0.22)
		"ring":
			_circle(0.5, 0.5, 0.3, false)
		"branch":
			_circle(0.3, 0.2, 0.08, false)
			_circle(0.3, 0.8, 0.08, false)
			_circle(0.72, 0.36, 0.08, false)
			_line([[0.3, 0.28], [0.3, 0.72]])
			_line([[0.72, 0.44], [0.72, 0.52], [0.36, 0.72]])
		"clock":
			_circle(0.5, 0.5, 0.36, false)
			_line([[0.5, 0.28], [0.5, 0.5], [0.66, 0.6]])
		"door":
			_rect(0.22, 0.12, 0.46, 0.78)
			_line([[0.68, 0.5], [0.86, 0.5]])
			_line([[0.78, 0.4], [0.88, 0.5], [0.78, 0.6]])
			_circle(0.56, 0.52, 0.04)
		"bell":
			_line([[0.24, 0.7], [0.3, 0.6], [0.3, 0.42], [0.4, 0.26], [0.5, 0.22], [0.6, 0.26], [0.7, 0.42], [0.7, 0.6], [0.76, 0.7], [0.24, 0.7]])
			_line([[0.44, 0.78], [0.56, 0.78]])
		"lab":
			_line([[0.38, 0.12], [0.62, 0.12]])
			_line([[0.42, 0.12], [0.42, 0.4], [0.16, 0.82], [0.2, 0.88], [0.8, 0.88], [0.84, 0.82], [0.58, 0.4], [0.58, 0.12]])
			_line([[0.28, 0.64], [0.72, 0.64]])
			_circle(0.44, 0.75, 0.04)
			_circle(0.58, 0.72, 0.03)
		"minus":
			_line([[0.24, 0.5], [0.76, 0.5]], 3.0)
		"maximize":
			_rect(0.21, 0.21, 0.58, 0.58)
		"restore":
			_line([[0.36, 0.33], [0.36, 0.18], [0.82, 0.18], [0.82, 0.64], [0.67, 0.64]])
			_rect(0.18, 0.36, 0.49, 0.46)
		"resize_grip":
			_line([[0.30, 0.78], [0.78, 0.30]])
			_line([[0.53, 0.78], [0.78, 0.53]])
		"relay":
			var art := Art.website("relay")
			if art != null:
				draw_texture_rect(art, Rect2(_p(0, 0), _p(1, 1) - _p(0, 0)), false)
		"left":
			_line([[0.74, 0.50], [0.29, 0.50], [0.48, 0.31]])
			_line([[0.29, 0.50], [0.48, 0.69]])
		"right":
			_line([[0.26, 0.50], [0.71, 0.50], [0.52, 0.31]])
			_line([[0.71, 0.50], [0.52, 0.69]])
		"globe":
			_circle(0.5, 0.5, 0.38, false)
			var s := minf(size.x, size.y)
			draw_arc(_p(0.5, 0.5), 0.38 * s, -PI / 2, PI / 2, 24, color, stroke * s / 24.0, true)
			_line([[0.12, 0.5], [0.88, 0.5]])
			_line([[0.5, 0.12], [0.5, 0.88]])
			var w := 0.17 * s
			var c := _p(0.5, 0.5)
			var pts := PackedVector2Array()
			for i in 25:
				var a := -PI / 2 + PI * i / 24.0
				pts.append(c + Vector2(cos(a) * w, sin(a) * 0.38 * s))
			draw_polyline(pts, color, stroke * s / 24.0, true)
			var pts2 := PackedVector2Array()
			for i in 25:
				var a := PI / 2 + PI * i / 24.0
				pts2.append(c + Vector2(cos(a) * w, sin(a) * 0.38 * s))
			draw_polyline(pts2, color, stroke * s / 24.0, true)
		"wifi":
			var s := minf(size.x, size.y)
			for i in 3:
				draw_arc(_p(0.5, 0.8), (0.16 + i * 0.18) * s, -PI * 0.78, -PI * 0.22, 16, color, stroke * s / 24.0, true)
			_circle(0.5, 0.8, 0.05)
