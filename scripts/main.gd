extends Control
## Room view: the player sits at a desk looking at a monitor.
## The in-game OS renders into a 2x supersampled SubViewport shown on the monitor.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const Room := preload("res://scripts/room/room.gd")
const ScreenShader := preload("res://shaders/screen.gdshader")

const VIEW := Vector2(1920, 1080)
const SCREEN := Vector2(1280, 720)
const SUPERSAMPLE := 2
const BEZEL := 14.0
const CHIN := 30.0
const MONITOR_TOP := 120.0
const FOCUS_SCALE := 1.45

var _rig: Control
var _room: Control
var _screen_off: ColorRect
var _led: ColorRect
var _desktop: Control
var _focused := false
var _hint: Label


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

	_room = Room.new()
	_rig.add_child(_room)
	_build_monitor()
	_build_props()
	_add_vignette()
	_power_on()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		_set_focus(not _focused)
		get_viewport().set_input_as_handled()


func _screen_center() -> Vector2:
	return Vector2(VIEW.x / 2.0, MONITOR_TOP + BEZEL + SCREEN.y / 2.0)


func _build_monitor() -> void:
	var frame_size := Vector2(SCREEN.x + BEZEL * 2.0, SCREEN.y + BEZEL + CHIN)
	var frame_pos := Vector2((VIEW.x - frame_size.x) / 2.0, MONITOR_TOP)
	_room.monitor_rect = Rect2(frame_pos, frame_size)

	var frame := Panel.new()
	var sb := UITheme.box(Color("16181d"), 12, Color("2b2e36"), 0, 2, 0)
	sb.shadow_size = 50
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_offset = Vector2(0, 14)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = frame_pos
	frame.size = frame_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(frame)
	# brushed chin highlight
	var chin := ColorRect.new()
	chin.color = Color(1, 1, 1, 0.025)
	chin.position = frame_pos + Vector2(14, frame_size.y - CHIN + 2)
	chin.size = Vector2(frame_size.x - 28, CHIN - 6)
	chin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(chin)

	var brand := UITheme.label("NEXORA", 11, Color("5a606c"))
	brand.add_theme_font_override("font", UITheme.font(false, true))
	brand.position = Vector2(VIEW.x / 2.0 - 26, frame_pos.y + frame_size.y - CHIN + 6)
	_rig.add_child(brand)

	_led = ColorRect.new()
	_led.color = Color("2a2d33")
	_led.position = Vector2(frame_pos.x + frame_size.x - 46, frame_pos.y + frame_size.y - CHIN / 2.0 - 2)
	_led.size = Vector2(12, 3)
	_rig.add_child(_led)

	# Screen: SubViewport rendered at 2x, displayed at 1x for crisp text and shapes.
	var screen_pos := frame_pos + Vector2(BEZEL, BEZEL)
	var container := SubViewportContainer.new()
	container.stretch = false
	container.position = screen_pos
	container.size = SCREEN * SUPERSAMPLE
	container.scale = Vector2.ONE / SUPERSAMPLE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var vp := SubViewport.new()
	vp.size = Vector2i(SCREEN * SUPERSAMPLE)
	vp.size_2d_override = Vector2i(SCREEN)
	vp.size_2d_override_stretch = true
	container.add_child(vp)
	_rig.add_child(container)

	_desktop = Desktop.new()
	_desktop.theme = theme
	_desktop.size = SCREEN
	_desktop.booted.connect(func() -> void: _set_focus(true))
	vp.add_child(_desktop)

	var fx := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = ScreenShader
	fx.material = mat
	fx.position = screen_pos
	fx.size = SCREEN
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(fx)

	_screen_off = ColorRect.new()
	_screen_off.color = Color(0.02, 0.02, 0.025, 1.0)
	_screen_off.position = screen_pos
	_screen_off.size = SCREEN
	_rig.add_child(_screen_off)


func _build_props() -> void:
	var frame: Rect2 = _room.monitor_rect
	_sticky(Vector2(frame.end.x - 10, frame.position.y + 70), "TODO\n- 위키 읽기\n- 첫 PR 올리기!", Color("f2d46b"), 0.07)
	_sticky(Vector2(frame.position.x - 122, frame.position.y + 420), "git pull\n먼저!!", Color("8fd3a8"), -0.06)

	# Coffee steam
	var steam := CPUParticles2D.new()
	steam.position = Vector2(420, 900 - 74)
	steam.amount = 14
	steam.lifetime = 2.6
	steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	steam.emission_rect_extents = Vector2(14, 2)
	steam.direction = Vector2(0, -1)
	steam.spread = 12
	steam.gravity = Vector2(0, -8)
	steam.initial_velocity_min = 14
	steam.initial_velocity_max = 24
	steam.scale_amount_min = 5
	steam.scale_amount_max = 9
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.3, Color(1, 1, 1, 0.12))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	steam.color_ramp = grad
	_rig.add_child(steam)

	_hint = UITheme.label("F2  ·  화면 가까이 보기 / 방 둘러보기", 13, Color("5c6370"))
	_hint.position = Vector2(VIEW.x / 2.0 - 130, 1040)
	_rig.add_child(_hint)


func _sticky(pos: Vector2, text: String, color: Color, rot: float) -> void:
	var note := PanelContainer.new()
	var sb := UITheme.box(color, 2, Color(0, 0, 0, 0), 10)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(2, 3)
	note.add_theme_stylebox_override("panel", sb)
	note.position = pos
	note.rotation = rot
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(UITheme.label(text, 13, color.darkened(0.75)))
	_rig.add_child(note)


func _add_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.add_point(0.65, Color(0, 0, 0, 0.0))
	grad.set_color(grad.get_point_count() - 1, Color(0, 0, 0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(1.05, 0.45)
	var v := TextureRect.new()
	v.texture = tex
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


## Intro: lean in towards the desk, the monitor powers on, the OS boots.
func _power_on() -> void:
	_rig.pivot_offset = _screen_center()
	_rig.scale = Vector2.ONE * 0.86
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.3)
	t.tween_property(_rig, "scale", Vector2.ONE, 1.6)
	t.tween_callback(func() -> void: _led.color = Color("3ddc84"))
	t.tween_interval(0.3)
	t.tween_property(_screen_off, "color:a", 0.0, 0.5)
	t.parallel().tween_method(func(v: float) -> void:
		_room.screen_glow = v
		_room.queue_redraw(), 0.0, 1.0, 0.8)
	t.tween_callback(_on_screen_on)


func _on_screen_on() -> void:
	_screen_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.boot()


## Lean in so the screen fills the view, or lean back to see the room.
func _set_focus(on: bool) -> void:
	_focused = on
	var target_scale := FOCUS_SCALE if on else 1.0
	var target_pos := Vector2(0, VIEW.y / 2.0 - _screen_center().y) if on else Vector2.ZERO
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "scale", Vector2.ONE * target_scale, 0.5)
	t.parallel().tween_property(_rig, "position", target_pos, 0.5)
