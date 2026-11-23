extends Node
## Desk view and workstation tiers: renders the real main scene (room + monitor + side monitor)
## at each tier and view mode. Isolated QA project only.

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
	# Power-on intro: lean in, screen turns on, desk view.
	var deadline := Time.get_ticks_msec() + 15000
	while _main.view_mode() == "room" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await pause(0.9)
	_main._desktop._boot.visible = false
	check(_main.view_mode() == "desk", "default working view is the desk, not a full-screen monitor")
	check(_main._side == null, "an intern has one monitor")
	var shown: float = _main.SCREEN.x * _main._rig.scale.x
	check(shown >= 1350.0 and shown < 1920.0, "monitor stays dominant while the desk shows around it")
	check(_main._rig.position.y + _main._rig.scale.y * 0.0 <= 0.0, "desk view keeps the screen near the top")
	await capture("desk_intern")

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

	_main._close_up = true
	_main._apply_view("close")
	await pause(0.8)
	check(_main.view_mode() == "close" and is_equal_approx(_main._rig.scale.x, _main.FOCUS_SCALE), "F2 close-up fills the view with the screen")
	await capture("desk_closeup")
	_main._close_up = false
	_main._set_focus(false)
	await pause(0.8)
	check(_main.view_mode() == "room", "leaning back shows the whole room")
	await capture("desk_room")

	# A loaded save replaces the state and emits time_changed.
	Game.reset_state()
	Game.time_changed.emit(Game.day(), Game.minutes())
	await pause(0.3)
	check(_main._side == null and _main._room.tier == 0, "loading an intern save returns to the intern desk")
	Game.state["rank"] = 1
	Game.time_changed.emit(Game.day(), Game.minutes())
	await pause(0.3)
	check(_main._side != null, "loading a promoted save restores the side monitor without a promotion event")
	while Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("DESK_QA: %d checks, %d failures" % [_checks, _failures])
	await pause(0.1)
	get_tree().quit(0 if _failures == 0 else 1)
