extends SubViewport
## The city GLB shares the room clock. Its façade material is evaluated in 3D at runtime.

const CITY := "res://content/models/room/city.glb"
const FACADES := preload("res://shaders/city_facade.gdshader")
const COLORS := ["777d87", "9fa6ae", "575f70", "a3a6a9", "8c8075", "b8babe"]

var _materials := {}
var _camera: Camera3D
var _day := -1.0
var _sunset := -1.0
var available := false


func _ready() -> void:
	size = Vector2i(759, 840)
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not ResourceLoader.exists(CITY, "PackedScene"):
		return
	var scene := load(CITY) as PackedScene
	var skyline := scene.instantiate()
	add_child(skyline)
	for mesh: MeshInstance3D in skyline.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i)
			if original != null:
				mesh.set_surface_override_material(i, _material(original.resource_name))
	_camera = Camera3D.new()
	_camera.fov = 63.0
	_camera.near = 1.0
	_camera.far = 2400.0
	_camera.position = Vector3(0, 65, 46)
	_camera.rotation_degrees.x = -4.0
	add_child(_camera)
	_camera.current = true
	available = true
	light(1.0, 0.0)


func _material(label: String) -> ShaderMaterial:
	if not _materials.has(label):
		var material := ShaderMaterial.new()
		material.shader = FACADES
		var kind := {"ground": 1, "street": 2, "hill": 3, "warn": 4, "roof": 5, "equipment": 5, "trees": 5}.get(label, 0) as int
		var paint := COLORS[clampi(label.trim_prefix("facade").get_slice(".", 0).to_int(), 0, COLORS.size() - 1)] as String
		var color: String = {"trees": "2e4c48", "roof": "687580", "equipment": "a0aeb0"}.get(label, "353d4b") if kind != 0 else paint
		material.set_shader_parameter("paint", Color(color))
		material.set_shader_parameter("surface_kind", kind)
		_materials[label] = material
	return _materials[label]


func light(day: float, sunset: float) -> void:
	if not available or (is_equal_approx(day, _day) and is_equal_approx(sunset, _sunset)):
		return
	_day = day
	_sunset = sunset
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter("daylight", day)
		material.set_shader_parameter("sunset", sunset)
	render_target_update_mode = SubViewport.UPDATE_ONCE


func lean(closer: bool) -> void:
	if available:
		_camera.position.x = 11.0 if closer else 0.0
		render_target_update_mode = SubViewport.UPDATE_ONCE
