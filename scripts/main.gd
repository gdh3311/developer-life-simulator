extends Control
## Room view: the player sits at a desk looking at a monitor.
## The whole in-game OS is rendered into a SubViewport shown on that monitor.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const ScreenShader := preload("res://shaders/screen.gdshader")

const VIEW := Vector2(1920, 1080)
const SCREEN := Vector2(1280, 720)
const BEZEL := 22.0
const CHIN := 42.0
const MONITOR_TOP := 110.0
const FOCUS_SCALE := 1.45

var _rig: Control          # everything in the room; scaled to "lean in" / "lean back"
var _glow: TextureRect     # monitor light spilling on the wall
var _screen_off: ColorRect # black panel covering the screen while powered off
var _led: ColorRect
var _desktop: Control
var _focused := false
var _time := 0.0


func _ready() -> void:
	theme = UITheme.build()

	var bg := ColorRect.new()
	bg.color = Color("07080b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_rig = Control.new()
	_rig.size = VIEW
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rig)

	_build_room()
	_build_monitor()
	_power_on()


func _process(delta: float) -> void:
	_time += delta
	# Subtle flicker of the screen light on the wall.
	_glow.self_modulate.a = 0.93 + 0.07 * sin(_time * 1.7) * sin(_time * 0.43)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		_set_focus(not _focused)
		get_viewport().set_input_as_handled()


func _screen_center() -> Vector2:
	return Vector2(VIEW.x / 2.0, MONITOR_TOP + BEZEL + SCREEN.y / 2.0)


func _build_room() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.38, 0.55, 1.0, 0.22))
	grad.set_color(1, Color(0.38, 0.55, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_glow = TextureRect.new()
	_glow.texture = tex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.position = Vector2(-240, -420)
	_glow.size = Vector2(2400, 1800)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.0
	_rig.add_child(_glow)

	var desk_y := MONITOR_TOP + SCREEN.y + BEZEL + CHIN + 40.0
	_rig.add_child(_rect(Color("15110e"), Vector2(-400, desk_y), Vector2(2720, 600)))
	_rig.add_child(_rect(Color("2a211a"), Vector2(-400, desk_y), Vector2(2720, 5)))

	# Keyboard, mouse and a coffee mug seen from the front.
	_rig.add_child(_panel(Color("1c1e23"), Vector2(VIEW.x / 2.0 - 330, desk_y + 52), Vector2(660, 26), 6))
	_rig.add_child(_panel(Color("1c1e23"), Vector2(VIEW.x / 2.0 + 400, desk_y + 50), Vector2(44, 28), 14))
	_rig.add_child(_panel(Color("6b3f2a"), Vector2(VIEW.x / 2.0 - 620, desk_y + 4), Vector2(64, 76), 8))
	_rig.add_child(_panel(Color("6b3f2a"), Vector2(VIEW.x / 2.0 - 566, desk_y + 18), Vector2(22, 38), 10))

	var hint := UITheme.label("F2   화면 가까이 보기 / 멀리 보기", 13, Color("4c5260"))
	hint.position = Vector2(VIEW.x / 2.0 - 120, desk_y + 100)
	_rig.add_child(hint)


func _build_monitor() -> void:
	var frame_size := Vector2(SCREEN.x + BEZEL * 2.0, SCREEN.y + BEZEL + CHIN)
	var frame_pos := Vector2((VIEW.x - frame_size.x) / 2.0, MONITOR_TOP)
	var bottom := frame_pos.y + frame_size.y

	# Stand (behind the frame).
	_rig.add_child(_panel(Color("1a1c21"), Vector2(VIEW.x / 2.0 - 55, bottom - 6), Vector2(110, 46), 4))
	_rig.add_child(_panel(Color("1f2127"), Vector2(VIEW.x / 2.0 - 170, bottom + 34), Vector2(340, 12), 6))

	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UITheme.box(Color("121419"), 16, Color("23262d"), 0, 2, 40))
	frame.position = frame_pos
	frame.size = frame_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(frame)

	var brand := UITheme.label("NEXORA", 11, Color("4a4f5a"))
	brand.position = Vector2(VIEW.x / 2.0 - 24, bottom - CHIN + 13)
	_rig.add_child(brand)

	_led = _rect(Color("2a2d33"), Vector2(frame_pos.x + frame_size.x - 60, bottom - CHIN / 2.0 - 2), Vector2(10, 4))
	_rig.add_child(_led)

	# Sticky note on the side of the monitor.
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", UITheme.box(Color("f2d46b"), 2, Color(0, 0, 0, 0), 10))
	note.position = Vector2(frame_pos.x + frame_size.x - 14, frame_pos.y + 60)
	note.rotation = 0.07
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(UITheme.label("TODO\n- 위키 읽기\n- 첫 PR 올리기!", 13, Color("3b3320")))
	_rig.add_child(note)

	# The screen itself: the game OS lives inside this SubViewport.
	var screen_pos := frame_pos + Vector2(BEZEL, BEZEL)
	var container := SubViewportContainer.new()
	container.position = screen_pos
	container.size = SCREEN
	container.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(SCREEN)
	container.add_child(vp)
	_rig.add_child(container)

	_desktop = Desktop.new()
	_desktop.theme = theme
	_desktop.size = SCREEN
	vp.add_child(_desktop)

	var fx := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = ScreenShader
	fx.material = mat
	fx.position = screen_pos
	fx.size = SCREEN
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(fx)

	_screen_off = _rect(Color(0.02, 0.02, 0.025, 1.0), screen_pos, SCREEN)
	_screen_off.mouse_filter = Control.MOUSE_FILTER_STOP
	_rig.add_child(_screen_off)


## Intro: lean in towards the desk, the monitor powers on, the OS boots.
func _power_on() -> void:
	_rig.pivot_offset = _screen_center()
	_rig.scale = Vector2.ONE * 0.8
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.4)
	t.tween_property(_rig, "scale", Vector2.ONE, 1.8)
	t.tween_callback(func() -> void: _led.color = Color("3ddc84"))
	t.tween_interval(0.35)
	t.tween_property(_screen_off, "color:a", 0.0, 0.5)
	t.parallel().tween_property(_glow, "modulate:a", 1.0, 0.8)
	t.tween_callback(_on_screen_on)


func _on_screen_on() -> void:
	_screen_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.boot()


## Lean in so the screen fills the view, or lean back to see the desk.
func _set_focus(on: bool) -> void:
	_focused = on
	var target_scale := FOCUS_SCALE if on else 1.0
	var target_pos := Vector2(0, VIEW.y / 2.0 - _screen_center().y) if on else Vector2.ZERO
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "scale", Vector2.ONE * target_scale, 0.45)
	t.parallel().tween_property(_rig, "position", target_pos, 0.45)


func _rect(color: Color, pos: Vector2, rect_size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = rect_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _panel(color: Color, pos: Vector2, rect_size: Vector2, radius: int) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UITheme.box(color, radius))
	p.position = pos
	p.size = rect_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
