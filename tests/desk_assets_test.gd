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
	check(DeskItems.slots().size() == 4 and DeskItems.catalog()["items"].size() >= 15, "the catalog lists four slots and the built-in items")
	var all_load: bool = DeskItems.catalog()["items"].all(func(it: Dictionary) -> bool: return DeskItems.texture(it) != null)
	check(all_load, "every built-in SVG loads as a texture")
	for slot in DeskItems.slots():
		check(eq(slot) == String(DeskItems.slot_info(slot)["default"]), "a new save uses the default " + slot)

	_main = MainScene.instantiate()
	get_tree().root.add_child.call_deferred(_main)
	var deadline := Time.get_ticks_msec() + 15000
	while (_main == null or not _main.is_inside_tree() or _main.view_mode() == "room") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await pause(0.9)
	_main._desktop._boot.visible = false
	for slot in DeskItems.slots():
		check(_main._room.equipped_texture(slot) != null, "the room draws the %s from its asset" % slot)
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
	Game.emit_event("purchase", {"id": "keyboard_rgb"})
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
	check(buttons.size() >= DeskItems.catalog()["items"].size(), "the Dashboard shows a choice for every item")
	await capture("desk_assets_dashboard")
	layer.queue_free()
	dash.free()

	# Save and load keep the choices.
	DirAccess.make_dir_recursive_absolute("user://sandbox")
	Game._save()
	var before: Dictionary = Game.state["desk"].duplicate()
	Game.state["desk"] = {}
	check(Game.load_game() and Game.state["desk"] == before, "desk choices survive save and load")

	for f in ["qa_mug.svg", "qa_mug.json", "sneaky.json", "wrong_slot.json"]:
		DirAccess.remove_absolute(DeskItems.CUSTOM_DIR.path_join(f))
	while Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("DESK_ASSETS_QA: %d checks, %d failures" % [_checks, _failures])
	await pause(0.1)
	get_tree().quit(0 if _failures == 0 else 1)
