extends SubViewport
## The desktop, mat, stands and props share one perspective camera and receive the same lights.

const DeskItems := preload("res://scripts/room/desk_items.gd")
const AREA := Rect2(-260, 420, 2440, 1080)
const MODEL_DIR := "res://content/models/desk/"
const WALNUT := preload("res://content/desk/walnut-surface.png")
const TOP := Rect2(-0.87, -0.37, 1.74, 0.555)
const PLACEMENT := Rect2(-0.77, -0.295, 1.54, 0.445)
const SLOT_POS := {"keyboard": Vector2(0, 0.028), "mouse": Vector2(0.343, 0.042),
	"mug": Vector2(-0.328, 0.062), "plant": Vector2(-0.663, -0.248)}
const SLOT_SCALE := {"keyboard": 1.15, "mouse": 0.91, "mug": 0.73, "plant": 0.80}

var _camera: Camera3D
var _props: Node3D
var _fill: DirectionalLight3D
var _window: DirectionalLight3D
var _lamp: OmniLight3D
var _monitor_light: OmniLight3D
var _ambience: Environment
var _side_stand: Node3D
var _nameplate: Label3D
var _mat_height := 0.002
var _instances := {}
var _scenes := {}


func _ready() -> void:
	size = Vector2i(AREA.size)
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ambience = Environment.new()
	_ambience.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_ambience.ambient_light_color = Color("ccd8ed")
	_ambience.ambient_light_energy = 0.45
	var environment := WorldEnvironment.new()
	environment.environment = _ambience
	add_child(environment)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = rad_to_deg(2.0 * atan(AREA.size.y / (2.0 * 1460.0)))
	_camera.near = 0.1
	_camera.far = 10.0
	add_child(_camera)
	_camera.position = Vector3(0, 0.50, 1.02)
	_camera.rotation_degrees.x = -25
	_camera.current = true
	_props = Node3D.new()
	add_child(_props)
	_build_worktop()
	_window = _key_light(Vector3(-32, -38, 0), Color("e4ecff"))
	_window.shadow_enabled = true
	_window.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_window.directional_shadow_max_distance = 2.4
	_window.shadow_bias = 0.035
	_window.shadow_normal_bias = 0.21
	_window.shadow_blur = 1.7
	_fill = _key_light(Vector3(-25, 36, 0), Color("a7c4ef"))
	_monitor_light = OmniLight3D.new()
	_monitor_light.position = Vector3(0.0, 0.22, -0.215)
	_monitor_light.light_color = Color("adc7ff")
	_monitor_light.omni_range = 1.0
	add_child(_monitor_light)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("ffc093")
	_lamp.light_energy = 0.44
	_lamp.omni_range = 0.22
	_lamp.omni_attenuation = 1.5
	_lamp.hide()
	add_child(_lamp)


func _build_worktop() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = WALNUT
	wood.albedo_color = Color("bba699")
	wood.roughness = 0.58
	var edge := wood.duplicate() as StandardMaterial3D
	edge.albedo_color = Color("826353")
	var center := TOP.get_center()
	var top := PlaneMesh.new()
	top.size = TOP.size
	var surface := MeshInstance3D.new()
	surface.mesh = top
	surface.material_override = wood
	surface.position = Vector3(center.x, 0.001, center.y)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	_slab(self, Vector3(center.x, -0.023, center.y), Vector3(TOP.size.x, 0.046, TOP.size.y), edge)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("272e35")
	steel.metallic = 0.35
	steel.roughness = 0.46
	_slab(self, Vector3(-0.76, -0.16, 0.103), Vector3(0.045, 0.29, 0.047), steel)
	_slab(self, Vector3(0.76, -0.16, 0.103), Vector3(0.045, 0.29, 0.047), steel)
	_stand(Vector2(0, -0.218), Vector2(0.305, 0.137), 0.165, steel)
	_side_stand = _stand(Vector2(0.688, -0.120), Vector2(0.174, 0.119), 0.2, steel)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("b49564")
	brass.metallic = 0.45
	brass.roughness = 0.56
	_nameplate = Label3D.new()
	_nameplate.position = Vector3(0.564, 0.030, 0.154)
	_nameplate.pixel_size = 0.00058
	_nameplate.font_size = 30
	_nameplate.outline_size = 0
	_nameplate.modulate = Color("302922")
	add_child(_nameplate)
	_slab(_nameplate, Vector3(0, -0.007, -0.013), Vector3(0.178, 0.047, 0.024), brass)


func _stand(point: Vector2, base: Vector2, height: float, material: Material) -> Node3D:
	var stand := Node3D.new()
	stand.position = Vector3(point.x, 0.004, point.y)
	add_child(stand)
	_slab(stand, Vector3(0, 0.006, 0.022), Vector3(base.x, 0.012, base.y), material)
	_slab(stand, Vector3(0, height * 0.5, -0.012), Vector3(0.043, height, 0.032), material)
	return stand


func _slab(parent: Node, point: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = point
	parent.add_child(piece)


func _key_light(angles: Vector3, color: Color) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = color
	add_child(light)
	return light


func lighting(day: float, dusk: float, monitor: float) -> void:
	_window.light_color = Color("eff5ff").lerp(Color("ffc395"), dusk)
	_window.light_energy = lerpf(0.36, 1.39, day)
	_fill.light_energy = 0.18 + 0.20 * monitor
	_monitor_light.light_energy = 0.50 * monitor
	_ambience.ambient_light_energy = lerpf(0.21, 0.42, day)
	render_target_update_mode = SubViewport.UPDATE_ONCE


func sync(slots: Array, placements: Array, tier: int) -> void:
	var keep := {}
	_lamp.hide()
	_side_stand.visible = tier >= 1
	_nameplate.visible = tier >= 2
	_nameplate.text = Game.pname().left(15)
	_mat_height = 0.002
	if tier < 1 and _pose("work_lamp", "scene_work_lamp", Vector2(0.682, -0.231), 0.0, Vector3.ONE * 0.79):
		keep["work_lamp"] = true
	var mat_id: String = DeskItems.equipped("mat").get("id", "mat_none")
	if mat_id == "mat_none" and tier >= 2:
		mat_id = "mat_navy"
	if mat_id != "mat_none" and _pose("mat", mat_id, Vector2(0, 0.004), 0.0, Vector3(1.68, 1.0, 1.23)):
		keep["mat"] = true
		_mat_height += _instances["mat"]["bounds"].size.y
	for slot: String in slots:
		var item := DeskItems.equipped(slot)
		if not item.is_empty() and not item.get("custom", false) and _pose(slot, item["id"], SLOT_POS[slot], 0.0, Vector3.ONE * float(SLOT_SCALE[slot])):
			keep[slot] = true
	for placement: Dictionary in placements:
		var id: String = placement["id"]
		var item := DeskItems.item(id)
		var point := Vector2(float(placement["x"]), float(placement["y"]))
		if not item.is_empty() and DeskItems.unlocked(item) and _pose(id, id, _world_position(point), float(placement.get("angle", 0)), Vector3.ONE * 0.70):
			keep[id] = true
			if id == "decor_task_lamp" and DeskItems.lamp_on():
				var record: Dictionary = _instances[id]
				var origin: Vector3 = record["pivot"].position
				_lamp.position = origin + Vector3.UP * record["pivot"].scale.y * record["bounds"].size.y * 0.70
				_lamp.show()
	for key in _instances.keys():
		if not keep.has(key):
			_instances[key]["pivot"].queue_free()
			_instances.erase(key)
	render_target_update_mode = SubViewport.UPDATE_ONCE


func visible_model(key: String) -> bool:
	return _instances.has(key)


func bounds_for(key: String, fallback: Rect2) -> Rect2:
	if not _instances.has(key):
		return fallback
	var record: Dictionary = _instances[key]
	return _project_bounds(record["bounds"], record["pivot"].transform)


func _world_position(point: Vector2) -> Vector2:
	var normalized := (point - DeskItems.DECOR_AREA.position) / DeskItems.DECOR_AREA.size
	return PLACEMENT.position + normalized * PLACEMENT.size


func canvas_point(point: Vector2) -> Vector2:
	var world := _world_position(point)
	return AREA.position + _camera.unproject_position(Vector3(world.x, 0.001, world.y))


func layout_point(pixel: Vector2) -> Vector2:
	var direction := _camera.project_ray_normal(pixel - AREA.position)
	if direction.y >= -0.0001:
		return Vector2(-INF, -INF)
	var hit := _camera.position + direction * ((_camera.position.y - 0.001) / -direction.y)
	return DeskItems.DECOR_AREA.position + (Vector2(hit.x, hit.z) - PLACEMENT.position) / PLACEMENT.size * DeskItems.DECOR_AREA.size


func pick(pixel: Vector2, candidates: Array) -> String:
	var direction := _camera.project_ray_normal(pixel - AREA.position)
	var best := INF
	var key := ""
	for candidate: String in candidates:
		if not _instances.has(candidate):
			continue
		var record: Dictionary = _instances[candidate]
		var pivot: Node3D = record["pivot"]
		var inverse := pivot.transform.affine_inverse()
		var ray := inverse * _camera.position
		var bounds: AABB = record["bounds"]
		var hit = bounds.grow(0.003).intersects_ray(ray, inverse.basis * direction)
		if hit is Vector3:
			var distance := _camera.position.distance_squared_to(pivot.transform * hit)
			if distance < best:
				best = distance
				key = candidate
	return key


func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var path := MODEL_DIR + id + ".glb"
		_scenes[id] = load(path) as PackedScene if ResourceLoader.exists(path, "PackedScene") else null
	return _scenes[id]


func _pose(key: String, id: String, point: Vector2, angle: float, dimensions: Vector3) -> bool:
	var scene := _scene(id)
	if scene == null:
		return false
	var record: Dictionary = _instances.get(key, {})
	if record.get("id", "") != id:
		if not record.is_empty():
			record["pivot"].queue_free()
		var pivot := Node3D.new()
		var model := scene.instantiate() as Node3D
		pivot.add_child(model)
		var bounds := _model_bounds(model, Transform3D.IDENTITY)
		var center := bounds.get_center()
		model.position -= Vector3(center.x, bounds.position.y, center.z)
		bounds.position -= Vector3(center.x, bounds.position.y, center.z)
		_props.add_child(pivot)
		record = {"id": id, "pivot": pivot, "bounds": bounds}
		_instances[key] = record
	var pivot: Node3D = record["pivot"]
	var on_mat := key != "mat" and Rect2(-0.45, -0.144, 0.90, 0.295).has_point(point)
	pivot.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(angle)) * Basis.from_scale(dimensions),
		Vector3(point.x, _mat_height if on_mat else 0.002, point.y))
	return true


func _project_bounds(bounds: AABB, pose: Transform3D) -> Rect2:
	var result := Rect2(_camera.unproject_position(pose * bounds.get_endpoint(0)), Vector2.ZERO)
	for i in range(1, 8):
		result = result.expand(_camera.unproject_position(pose * bounds.get_endpoint(i)))
	result.position += AREA.position
	return result


func _model_bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var local := parent_transform * node.transform
	var bounds := AABB()
	if node is MeshInstance3D and node.mesh != null:
		bounds = local * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var other := _model_bounds(child, local)
			if other.has_surface():
				bounds = bounds.merge(other) if bounds.has_surface() else other
	return bounds


