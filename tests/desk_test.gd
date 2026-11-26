extends Node
## Exercises the real seated view, monitor controls, and workstation tiers in an isolated project.

const MainScene := preload("res://scenes/main.tscn")
var _checks := 0
var _failures := 0
var _main: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("DESK_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func pause(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.reset_state()
	Game.state["player_name"] = "Desk Tester"
	Game.set_time(14 * 60)
	_main = MainScene.instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	check(_main.view_mode() == "desk" and not _main._screen_powered, "first frame is at the desk before power-on")
	var deadline := Time.get_ticks_msec() + 15000
	while not _main._screen_powered and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await pause(0.9)
	_main._desktop._boot.visible = false
	check(_main._screen_powered and _main.view_mode() == "desk", "power-on retains the seated view")
	check(_main._side == null, "an intern has one monitor")
	var shown: float = _main.SCREEN.x * _main._rig.scale.x
	check(shown >= 1250.0 and shown <= 1400.0, "the main monitor leaves room for the desk and surroundings")
	var worktop: Array[Node] = _main._room._models.find_children("*", "MeshInstance3D", false, false)
	check(worktop.any(func(piece: MeshInstance3D) -> bool:
		return piece.mesh is PlaneMesh and piece.material_override.albedo_texture == _main._room._models.WALNUT),
		"the perspective worktop uses the walnut material")
	await capture("desk_intern")

	check((await Workspace.prepare())["ok"], "the test desk mounts its isolated company repository")
	var ide_button: Control = _main._desktop._dock_buttons["ide"]
	var screen_origin: Vector2 = _main._room.monitor_rect.position + Vector2.ONE * _main.BEZEL
	var desk_transform: Transform2D = _main._rig.get_global_transform_with_canvas()
	click_at(desk_transform * (screen_origin + ide_button.get_global_rect().get_center()))
	await pause(0.35)
	check(_main._desktop.top_window_app() == "ide" and _main.view_mode() == "desk", "clicking the physical monitor opens DevIDE in the seated view")
	var editor = _main._desktop._find_method(_main._desktop, "open_file")
	if editor != null:
		editor.open_file("src/orders/orders.ts")
		check("export function" in editor._code.text, "the monitor editor shows the actual TypeScript source")
		await capture("desk_ide")
	else:
		check(false, "the monitor opens a source editor")

	Game.state["rank"] = 1
	Game.emit_event("promoted", {})
	await pause(0.8)
	check(_main._side != null and _main._room.tier == 1, "promotion installs the portrait side monitor")
	await pause(0.3)
	await capture("desk_junior")

	Game.state["rank"] = 2
	Game.emit_event("promoted", {})
	Game.set_time(19 * 60)
	await pause(0.8)
	check(_main._room.tier == 2, "tier two adds the desk mat and nameplate")
	await capture("desk_tier2_evening")

	_main._desktop._toasts.hide()
	press_key(KEY_F2)
	await pause(0.45)
	check(_main.view_mode() == "close" and is_equal_approx(_main._rig.scale.x, _main.FOCUS_SCALE), "F2 moves closer to the monitor")
	var close_transform: Transform2D = _main._rig.get_global_transform_with_canvas()
	var frame: Rect2 = _main._room.monitor_rect
	var desk_edge := close_transform * Vector2(0.0, 900.0)
	var visible_area := Rect2(Vector2.ZERO, _main.VIEW)
	check(visible_area.has_point(close_transform * frame.position) and visible_area.has_point(close_transform * frame.end)
		and desk_edge.y < _main.VIEW.y - 60.0, "the monitor frame and a strip of the desk stay visible when zoomed")
	await capture("desk_closeup")
	var view_action: Control = _main._desktop._view_action
	click_at(close_transform * (screen_origin + view_action.get_global_rect().get_center()))
	await pause(0.45)
	check(_main.view_mode() == "desk", "the workstation view control returns to the seated view")

	# A loaded save replaces the state and emits time_changed.
	Game.reset_state()
	Game.time_changed.emit(Game.day(), Game.minutes())
	await pause(0.3)
	check(_main._side == null and _main._room.tier == 0, "loading an intern save returns to the intern desk")
	Game.state["rank"] = 1
	Game.time_changed.emit(Game.day(), Game.minutes())
	await pause(0.3)
	check(_main._side != null, "loading a promoted save restores the side monitor without a promotion event")
	press_key(KEY_F3)
	await pause(0.35)
	check(_main._desktop.top_window_app() == "browser", "F3 reaches Relay through the actual monitor viewport")
	var arcade = _main._desktop._find_method(_main._desktop, "_select_product")
	if arcade != null:
		press_key(KEY_RIGHT)
		await pause(0.1)
		check(arcade._board.moves == 1, "a keyboard move reaches the focused arcade board through the monitor")
		await capture("desk_packet_run")
	else:
		check(false, "the monitor opens a playable arcade page")
	press_key(KEY_F2)
	await pause(0.4)
	await _main.night_transition()
	check(_main.view_mode() == "desk" and not _main._screen_powered and is_equal_approx(_main._screen_off.color.a, 1.0), "clock-out powers off the monitor from the seated view")
	await _main.morning_transition()
	check(_main.view_mode() == "desk" and _main._screen_powered, "the next morning starts at the same desk")
	while Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("DESK_QA: %d checks, %d failures" % [_checks, _failures])
	await pause(0.1)
	get_tree().quit(0 if _failures == 0 else 1)


func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)


func click_at(viewport_position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = viewport_position
	click.global_position = viewport_position
	click.pressed = true
	get_viewport().push_input(click, true)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release, true)
