extends Node
## Desk item assets: catalog, unlock rules, old-save fallback, purchases, custom player assets
## (including a rejected path traversal), the Dashboard picker, and real room renders.

const MainScene := preload("res://scenes/main.tscn")
const DeskItems := preload("res://scripts/room/desk_items.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Dashboard := preload("res://scripts/apps/dashboard_app.gd")
var _checks := 0
var _failures := 0
var _main: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("DESKASSET_CHECK: ", message, " = ", ok)
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


func eq(slot: String) -> String:
	return String(DeskItems.equipped(slot).get("id", ""))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Game.reset_state()
	Game.state["player_name"] = "Desk Tester"
	Game.set_time(15 * 60)
	DeskItems.reload()
	check(DeskItems.slots().size() == 5 and DeskItems.catalog()["items"].size() >= 31, "the catalog lists five slots, the built-in items, mats and toys")
	check(DeskItems.decor_items().size() == 14, "fourteen collectible props")
	var all_load: bool = DeskItems.catalog()["items"].all(func(it: Dictionary) -> bool: return DeskItems.texture(it) != null)
	check(all_load, "every built-in item loads as a texture")
	for slot in DeskItems.slots():
		check(eq(slot) == String(DeskItems.slot_info(slot)["default"]), "a new save uses the default " + slot)

	_main = MainScene.instantiate()
	get_tree().root.add_child.call_deferred(_main)
	var deadline := Time.get_ticks_msec() + 15000
	while (not _main.is_inside_tree() or not _main._screen_powered) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await pause(0.9)
	_main._desktop._boot.visible = false
	_main._desktop._toasts.hide()
	for slot in DeskItems.slots():
		check(_main._room.equipped_texture(slot) != null, "the room draws the %s from its asset" % slot)
	check(_main._room._city.available, "the city is loaded as a live 3D scene")
	check(_main._room._models.visible_model("work_lamp"), "the default articulated desk lamp uses a live mesh")
	for slot in _main._room.MODEL_SLOTS:
		check(_main._room._models.visible_model(slot), "the %s uses a live mesh" % slot)
	await capture("desk_assets_default")

	# Unlock rules.
	check(not DeskItems.equip("keyboard", "kb_retro"), "the retro keyboard is locked for interns")
	Game.state["rank"] = 2
	check(DeskItems.equip("keyboard", "kb_retro") and eq("keyboard") == "kb_retro", "reaching Junior II unlocks the retro keyboard")
	check(not DeskItems.equip("mug", "mug_moonlight"), "the Moonlight mug needs Chapter 2's ending")
	Game.state["story"]["c02_08"] = {"status": "done", "obj": {}, "data": {}}
	check(DeskItems.equip("mug", "mug_moonlight"), "finishing Chapter 2 unlocks the Moonlight gift mug")
	check(not DeskItems.equip("mouse", "kb_white"), "an item can't go into another slot")

	# Old save with a purchased keyboard and no desk choices.
	Game.state["desk"] = {}
	Game.state["owned"]["keyboard_rgb"] = true
	check(eq("keyboard") == "kb_rgb", "older saves keep showing the RGB keyboard they bought")
	Game.state["owned"].erase("keyboard_rgb")
	Game.state["desk"]["keyboard"] = "kb_rgb"
	check(eq("keyboard") == "kb_basic", "an item that's no longer unlocked falls back to the default")
	Game.state["owned"]["keyboard_rgb"] = true
	Game.state["desk"]["keyboard"] = "kb_white"
	Game.emit_event("purchase", {"item": "keyboard_rgb"})
	check(eq("keyboard") == "kb_rgb", "buying the RGB keyboard puts it on the desk")

	DeskItems.equip("mouse", "mouse_gaming")
	DeskItems.equip("plant", "plant_cactus")
	await pause(0.2)
	await capture("desk_assets_custom_set")

	# Custom player assets.
	DirAccess.make_dir_recursive_absolute(DeskItems.CUSTOM_DIR)
	_write(DeskItems.CUSTOM_DIR.path_join("qa_mug.svg"), '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="160" viewBox="0 0 96 80"><rect x="18" y="8" width="60" height="72" rx="6" fill="#ff7a59"/><circle cx="48" cy="44" r="12" fill="#fff3c4"/></svg>')
	_write(DeskItems.CUSTOM_DIR.path_join("qa_mug.json"), JSON.stringify({"slot": "mug", "name": {"ko": "QA 머그", "en": "QA mug"}, "image": "qa_mug.svg", "size": [96, 80]}))
	_write(DeskItems.CUSTOM_DIR.path_join("sneaky.json"), JSON.stringify({"slot": "mug", "name": "sneaky", "image": "../save.json", "size": [96, 80]}))
	_write(DeskItems.CUSTOM_DIR.path_join("wrong_slot.json"), JSON.stringify({"slot": "monitor", "name": "x", "image": "qa_mug.svg", "size": [96, 80]}))
	DeskItems.reload()
	var custom := DeskItems.item("custom_qa_mug")
	check(not custom.is_empty() and DeskItems.unlocked(custom) and DeskItems.texture(custom) != null, "a custom SVG item loads and is unlocked")
	check(DeskItems.item("custom_sneaky").is_empty() and DeskItems.item("custom_wrong_slot").is_empty(), "custom items outside the folder or with unknown slots are ignored")
	check(DeskItems.equip("mug", "custom_qa_mug") and _main._room.equipped_texture("mug") == DeskItems.texture(custom), "the custom mug is on the desk")
	await pause(0.2)
	await capture("desk_assets_player_mug")

	# Dashboard picker.
	var dash := Dashboard.new()
	dash.theme = UITheme.build()
	var panel: Control = dash._desk_panel()
	panel.position = Vector2(30, 30)
	panel.size = Vector2(900, 0)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(panel)
	await get_tree().process_frame
	var buttons := panel.find_children("*", "Button", true, false)
	var slot_items: int = DeskItems.catalog()["items"].filter(func(it: Dictionary) -> bool: return it["slot"] != "decor").size()
	check(buttons.size() >= slot_items, "the Dashboard shows a choice for every slot item")
	var arrange: Button
	for button: Button in buttons:
		if button.text == Game.L("배치 미리보기", "Arrange desk"):
			arrange = button
	check(arrange != null, "Dashboard provides a placement entry point")
	await capture("desk_assets_dashboard")
	if arrange != null:
		arrange.pressed.emit()
		check(is_instance_valid(_main._studio), "the Dashboard action opens the physical placement preview")
		_main._studio.close()
		await get_tree().process_frame
	layer.queue_free()
	dash.free()

	await _decorate()

	# Save and load keep the choices.
	DirAccess.make_dir_recursive_absolute("user://sandbox")
	Game._save()
	var before: Dictionary = Game.state["desk"].duplicate()
	Game.state["desk"] = {}
	check(Game.load_game() and Game.state["desk"] == before, "desk choices survive save and load")

	for f in ["qa_mug.svg", "qa_mug.json", "sneaky.json", "wrong_slot.json"]:
		DirAccess.remove_absolute(DeskItems.CUSTOM_DIR.path_join(f))
	# Release cached textures (static) before exit so nothing outlives the engine's leak check.
	DeskItems.reload()
	_main.queue_free()
	# Let the scene's tweens and timers finish before quitting.
	await pause(0.8)
	while Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("DESK_ASSETS_QA: %d checks, %d failures" % [_checks, _failures])
	await pause(0.1)
	get_tree().quit(0 if _failures == 0 else 1)


## Decorating mode: collectible unlocks, drag from the tray, move, put away, the desk limit, swapping.
func _decorate() -> void:
	var duck := DeskItems.item("decor_duck")
	check(not DeskItems.unlocked(duck) and DeskItems.lock_reason(duck).contains("작은 일감"), "the debugging duck waits for the first small ticket")
	check(DeskItems.unlocked(DeskItems.item("decor_pen_cup")) and DeskItems.unlocked(DeskItems.item("decor_clock")), "two starter toys are free")
	DeskItems.newly_unlocked()  # whatever is open now has been seen
	Game.state["tickets"] = {"active": "", "done": {"t01": {"minutes": 40}}, "taken": {}}
	Game.emit_event("ticket_done", {"ticket": "t01"})
	check(DeskItems.unlocked(duck) and "decor_duck" in Game.state["desk"].get("seen", []), "finishing a ticket unlocks the duck and announces it once")
	check(DeskItems.newly_unlocked().is_empty(), "the announcement doesn't repeat")
	_main._desktop.open_resource("browser", "shop")
	var browser = _main._desktop._find_method(_main._desktop._open["browser"], "open_page")
	for button: Button in browser.find_children("*", "Button", true, false):
		if button.text == Game.L("내 책상 배치", "Arrange my desk"):
			button.pressed.emit()
			break
	var studio: Control = _main._studio
	await pause(0.3)
	check(is_instance_valid(studio) and _main._view == "desk", "Shoply opens the same desk preview")
	if not is_instance_valid(studio):
		return
	check(not browser.is_slacking(), "the Shoply placement preview is a desk setting")
	check(studio._tray.get_child_count() == DeskItems.decor_items().size(), "the tray shows the whole collection, locked ones as silhouettes")
	await capture("desk_studio_open")
	# From the tray onto the desk.
	studio._begin("decor_duck", true)
	studio.move_drag(Vector2(640, 1010))
	studio._rotate(30.0)
	check(not DeskItems.is_placed("decor_duck") and _main._room._models.visible_model("decor_duck"), "dragged model is visible before it is saved")
	studio._drop(_main._room.canvas_point(Vector2(640, 1010)))
	var spot: Array = DeskItems.placed().filter(func(p: Dictionary) -> bool: return p["id"] == "decor_duck")
	check(spot.size() == 1 and roundi(float(spot[0]["x"])) == 640 and is_equal_approx(float(spot[0]["angle"]), 30.0), "drop saves the position and rotation")
	studio._begin("decor_duck", false)
	studio.move_drag(Vector2(600, 1000))
	studio._cancel_drag()
	check(roundi(float(spot[0]["x"])) == 640 and _main._room._preview.is_empty(), "cancelling a drag preserves the saved position")
	studio._begin("decor_pen_cup", true)
	studio._drop(_main._room.canvas_point(Vector2(1240, 930)))
	studio._begin("decor_clock", true)
	studio._drop(_main._room.canvas_point(Vector2(1660, 1050)))
	# Move, then put away by dragging it off the desk.
	studio._begin("decor_duck", false)
	studio.move_drag(Vector2(575, 1066))
	studio._drop(_main._room.canvas_point(Vector2(575, 1066)))
	check(roundi(float(DeskItems.placed().filter(func(p: Dictionary) -> bool: return p["id"] == "decor_duck")[0]["x"])) == 575, "a placed toy can be moved")
	studio._begin("decor_duck", false)
	studio.move_drag(Vector2(575, 925))
	var far_width: float = _main._room.prop_bounds("decor_duck", Rect2()).size.x
	studio.move_drag(Vector2(575, 1060))
	check(_main._room.prop_bounds("decor_duck", Rect2()).size.x > far_width * 1.12, "a prop grows in perspective toward the front")
	studio._cancel_drag()
	studio._begin("decor_clock", false)
	studio._drop(Vector2(1660, 600))
	check(not DeskItems.is_placed("decor_clock"), "dragging a toy off the desk puts it away")
	# Unlock the rest through what they stand for, then hit the desk limit.
	for a in ["moonlight", "launch", "game_dev", "perfect_day", "specialist"]:
		Story.career.st()["achievements"][a] = Game.day()
	var spots := {"decor_clock": Vector2(330, 990), "decor_lucky_cat": Vector2(1610, 1000), "decor_rocket": Vector2(1790, 1030), "decor_trophy": Vector2(1530, 1068)}
	for id in spots:
		check(DeskItems.place(id, spots[id]), "placed " + id)
	check(DeskItems.placed().size() == DeskItems.MAX_DECOR and not DeskItems.place("decor_bonsai", Vector2(900, 960)), "the desk holds six toys at most")
	check(not DeskItems.place("decor_snowglobe", Vector2(900, 960)), "a still-locked toy can't be placed")
	# Swap desk items by clicking them.
	var before := String(DeskItems.equipped("mug")["id"])
	studio._cycle("mug")
	check(String(DeskItems.equipped("mug")["id"]) != before, "clicking the mug swaps it for the next one")
	DeskItems.equip("mat", "mat_navy")
	await pause(0.3)
	await capture("desk_studio_decorated")
	DeskItems.remove("decor_rocket")
	DeskItems.remove("decor_clock")
	DeskItems.remove("decor_lucky_cat")
	var selectors := studio.find_children("*", "OptionButton", true, false) as Array
	selectors[0].item_selected.emit(3)
	check(eq("keyboard") == "kb_moss" and eq("mat") == "mat_navy", "the set picker equips the Moss keyboard and matching mat")
	check(DeskItems.place("decor_task_lamp", Vector2(1700, 1015), 20.0), "the mushroom lamp can be placed")
	check(DeskItems.place("decor_film_camera", Vector2(1540, 956), -35.0), "the film camera can be placed and turned")
	check(DeskItems.place("decor_notebook", Vector2(315, 1050), 18.0), "the notebook can be placed and turned")
	check(_main._room._models._lamp.visible and studio._lamp.visible, "placing the lamp adds a local 3D light and control")
	studio._lamp.button_pressed = false
	check(not _main._room._models._lamp.visible and not DeskItems.lamp_on(), "the studio switch turns the desk light off")
	studio._lamp.button_pressed = true
	studio.close()
	await pause(0.3)
	check(not is_instance_valid(studio) or studio.is_queued_for_deletion(), "Done closes decorating mode")
	await capture("desk_decorated")
	Game.set_time(18 * 60 + 45)
	await pause(0.2)
	await capture("desk_city_twilight")
	Game.set_time(20 * 60 + 10)
	await pause(0.2)
	await capture("desk_city_night")
