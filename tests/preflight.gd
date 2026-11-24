extends Node

const Gameplay := preload("res://tests/gameplay_test.gd")
const Chapter := preload("res://tests/chapter_test.gd")
const Recovery := preload("res://tests/recovery_test.gd")
const Chapter2 := preload("res://tests/chapter2_test.gd")
const Desk := preload("res://tests/desk_test.gd")
const Browser := preload("res://tests/browser_test.gd")
const Chapter3 := preload("res://tests/chapter3_test.gd")
const Events := preload("res://tests/events_test.gd")
const DeskAssets := preload("res://tests/desk_assets_test.gd")
const Arcade := preload("res://tests/arcade_test.gd")
const Studio := preload("res://tests/studio_test.gd")
const MainScene := preload("res://scenes/main.tscn")


func _ready() -> void:
	while Sfx._music.stream == null:
		await get_tree().process_frame
	print("QA_PREFLIGHT_OK")
	get_tree().quit()
