extends Control
## Room view: the player sits at a desk looking at a monitor.
## The in-game OS renders into a 2x supersampled SubViewport shown on the monitor.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const Room := preload("res://scripts/room/room.gd")
const SideScreen := preload("res://scripts/room/side_screen.gd")
const ScreenShader := preload("res://shaders/screen.gdshader")

const VIEW := Vector2(1920, 1080)
const SCREEN := Vector2(1280, 720)
const SUPERSAMPLE := 2
const BEZEL := 14.0
const CHIN := 30.0
const MONITOR_TOP := 120.0
const FOCUS_SCALE := 1.45      # close-up: the screen fills the view
const DESK_SCALE := 1.08       # default play view: monitor in front, desk and room around it
const DESK_TOP := 40.0         # screen top edge in the desk view
## Portrait side monitor (workstation tier 1+), right of the main monitor.
const SIDE_SCREEN := Vector2(264, 470)
const SIDE_BEZEL := 12.0
const SIDE_POS := Vector2(1632, 300)

var _rig: Control
var _room: Control
var _screen_off: ColorRect
var _led: ColorRect
var _desktop: Control
var _focused := false
var _view := "room"            # room | desk | close
var _close_up := false         # F2 preference while working
var _side: Control             # side monitor rig (null below tier 1)
var _tier := -1
var _hint: Label
var _fade: ColorRect
var _shadow: Control


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
	_update_workstation(true)
	Game.state_reset.connect(func() -> void: _update_workstation(true))
	# load_game() replaces the state and announces it through time_changed.
	Game.time_changed.connect(func(_d: int, _m: int) -> void: _update_workstation(true))
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind == "promoted":
			_update_workstation(false))
	_add_vignette()
	_shadow = _make_shadow()
	add_child(_shadow)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_power_on()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		if not _focused:
			_set_focus(true)
		else:
			_close_up = not _close_up
			_apply_view("close" if _close_up else "desk")
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

	_hint = UITheme.label("F2  ·  화면 가까이 보기 / 책상 보기", 13, Color("5c6370"))
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
	t.tween_callback(func() -> void:
		_led.color = Color("3ddc84")
		Sfx.play("power"))
	t.tween_interval(0.3)
	t.tween_property(_screen_off, "color:a", 0.0, 0.5)
	t.parallel().tween_method(func(v: float) -> void:
		_room.screen_glow = v
		_room.queue_redraw(), 0.0, 1.0, 0.8)
	t.tween_callback(_on_screen_on)


func _on_screen_on() -> void:
	_screen_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_focus(true)
	_desktop.boot()


# --- Effects -----------------------------------------------------------------

func shake(strength := 8.0) -> void:
	var base := _rig.position
	var t := create_tween()
	for i in 7:
		var k := 1.0 - i / 7.0
		t.tween_property(_rig, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.035)
	t.tween_property(_rig, "position", base, 0.05)


## A silhouette walking behind the chair (reflected over the whole view).
func _make_shadow() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(420, 1000)
	c.position = Vector2(-700, 280)
	c.modulate = Color(0, 0, 0, 0.0)
	c.draw.connect(func() -> void:
		c.draw_circle(Vector2(210, 120), 85, Color.WHITE)
		c.draw_colored_polygon(PackedVector2Array([Vector2(80, 230), Vector2(340, 230), Vector2(400, 1000), Vector2(20, 1000)]), Color.WHITE)
		c.draw_circle(Vector2(210, 250), 130, Color.WHITE))
	return c


func boss_pass() -> void:
	_shadow.position = Vector2(-700, 300)
	var t := create_tween()
	t.tween_property(_shadow, "modulate:a", 0.32, 0.6)
	t.parallel().tween_property(_shadow, "position:x", VIEW.x + 300, 3.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(func(v: float) -> void: _shadow.position.y = 300 + sin(v * 18.0) * 10.0, 0.0, 1.0, 3.6)
	t.tween_property(_shadow, "modulate:a", 0.0, 0.3)


## Clock-out: lean back, the monitor turns off, the window fades to night.
func night_transition() -> void:
	_set_focus(false)
	await get_tree().create_timer(0.6).timeout
	Sfx.play("power", 0.8)
	Sfx.muffle(true)
	_led.color = Color("2a2d33")
	var t := create_tween()
	t.tween_property(_screen_off, "color:a", 1.0, 0.4)
	t.parallel().tween_method(func(v: float) -> void:
		_room.screen_glow = v
		_room.queue_redraw(), 1.0, 0.0, 0.6)
	t.tween_method(func(v: float) -> void:
		_room.time_override = v
		_room.queue_redraw(), float(Game.minutes()), 23.0 * 60.0, 2.2)
	t.tween_interval(0.5)
	t.tween_property(_fade, "color:a", 1.0, 0.7)
	await t.finished


## Next morning: sunrise in the window, the monitor powers on, lean in.
func morning_transition() -> void:
	_room.time_override = 6.0 * 60.0
	_room.queue_redraw()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.7)
	t.tween_method(func(v: float) -> void:
		_room.time_override = v
		_room.queue_redraw(), 6.0 * 60.0, float(Game.minutes()), 1.8)
	t.tween_callback(func() -> void:
		_room.time_override = -1.0
		_led.color = Color("3ddc84")
		Sfx.play("power")
		Sfx.muffle(false))
	t.tween_property(_screen_off, "color:a", 0.0, 0.4)
	t.parallel().tween_method(func(v: float) -> void:
		_room.screen_glow = v
		_room.queue_redraw(), 0.0, 1.0, 0.6)
	await t.finished
	_screen_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_focus(true)
	await get_tree().create_timer(0.5).timeout


## Sit at the desk (working view) or lean back to see the room.
func _set_focus(on: bool) -> void:
	_focused = on
	_apply_view(("close" if _close_up else "desk") if on else "room")


## room: the whole office (scale 1). desk: the monitor in front with the desk, window and
## props around it. close: the screen fills the view.
func _apply_view(mode: String, instant := false) -> void:
	_view = mode
	var target_scale := 1.0
	var target_pos := Vector2.ZERO
	match mode:
		"close":
			target_scale = FOCUS_SCALE
			target_pos = Vector2(0, VIEW.y / 2.0 - _screen_center().y)
		"desk":
			target_scale = DESK_SCALE
			var c := _screen_center()
			# Pivot is the screen center; keep the screen top just below the view's top edge.
			target_pos = Vector2(-60.0 if _side != null else 0.0, DESK_TOP - (c.y - SCREEN.y / 2.0 * DESK_SCALE))
	if instant:
		_rig.scale = Vector2.ONE * target_scale
		_rig.position = target_pos
		return
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "scale", Vector2.ONE * target_scale, 0.5)
	t.parallel().tween_property(_rig, "position", target_pos, 0.5)


func view_mode() -> String:
	return _view


# --- Workstation tiers ------------------------------------------------------------
## 0 intern: one monitor · 1 junior: + portrait side monitor · 2+: desk mat and nameplate.
static func tier_for(rank: int) -> int:
	return clampi(rank, 0, 2)


func _update_workstation(silent: bool) -> void:
	var tier := tier_for(int(Game.state.get("rank", 0)))
	if tier == _tier:
		return
	var upgraded := _tier >= 0 and tier > _tier
	_tier = tier
	_room.tier = tier
	_room.queue_redraw()
	if tier >= 1 and _side == null:
		_build_side_monitor()
	elif tier < 1 and _side != null:
		_side.queue_free()
		_side = null
	if _focused:
		_apply_view(_view)
	if upgraded and not silent:
		Game.notify("tasks", Game.L("워크스테이션 업그레이드", "Workstation upgrade"),
			Game.L("보조 모니터가 설치됐습니다. 업무 상태가 오른쪽 화면에 표시됩니다.", "A side monitor was installed. Your work status shows on the right.") if tier == 1
			else Game.L("모니터 암과 데스크 매트, 명패가 생겼습니다.", "You got a monitor arm, a desk mat and a nameplate."))


func _build_side_monitor() -> void:
	_side = Control.new()
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_side)
	_rig.move_child(_side, _room.get_index() + 1)
	var frame_size := SIDE_SCREEN + Vector2(SIDE_BEZEL * 2.0, SIDE_BEZEL * 2.0)
	_room.side_rect = Rect2(SIDE_POS, frame_size)
	var frame := Panel.new()
	var sb := UITheme.box(Color("16181d"), 10, Color("2b2e36"), 0, 2, 0)
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 10)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = SIDE_POS
	frame.size = frame_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = false
	container.position = SIDE_POS + Vector2(SIDE_BEZEL, SIDE_BEZEL)
	container.size = SIDE_SCREEN * SUPERSAMPLE
	container.scale = Vector2.ONE / SUPERSAMPLE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var vp := SubViewport.new()
	vp.size = Vector2i(SIDE_SCREEN * SUPERSAMPLE)
	vp.size_2d_override = Vector2i(SIDE_SCREEN)
	vp.size_2d_override_stretch = true
	vp.gui_disable_input = true
	container.add_child(vp)
	_side.add_child(container)
	var screen := SideScreen.new()
	screen.theme = theme
	screen.size = SIDE_SCREEN
	vp.add_child(screen)
	var fx := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = ScreenShader
	fx.material = mat
	fx.position = container.position
	fx.size = SIDE_SCREEN
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_child(fx)
