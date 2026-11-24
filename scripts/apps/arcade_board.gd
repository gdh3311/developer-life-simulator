extends Control
## Packet Run. All movement and exit decisions use the current build's rules.

signal changed
signal cleared

const Rules := preload("res://scripts/services/arcade_rules.gd")
const Art := preload("res://scripts/ui/illustrations.gd")
const ACCENT := Color("9ce8d6")

var level := {}
var tile := Vector2i.ZERO
var moves := 0
var mask := 0
var status := "ready"
var _route: Array[Vector2i] = []
var _history: Array[int] = []
var _sprites: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	custom_minimum_size.y = 194
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for id in Art.ARCADE_ORDER:
		_sprites[id] = Art.arcade(id)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func load_level(artifact: Dictionary) -> void:
	level = Rules.unpack(artifact)
	reset_run()


func reset_run() -> void:
	if level.is_empty():
		return
	tile = level["start"]
	moves = 0
	mask = 0
	status = "ready"
	_route.assign([tile])
	_history.clear()
	_update()


func undo() -> void:
	if _history.is_empty():
		return
	_route.pop_back()
	tile = _route.back()
	mask = _history.pop_back()
	moves -= 1
	status = "ready"
	_update()


func move(direction: Vector2i) -> bool:
	if level.is_empty() or direction not in Rules.DIRECTIONS or status in ["cleared", "spent"]:
		return false
	var destination := tile + direction
	if not Rules.walkable(level, destination):
		status = "wall"
		_update()
		return false
	if destination == level["finish"] and not Rules.can_exit(level, mask):
		status = "locked"
		_update()
		return false
	_history.append(mask)
	tile = destination
	moves += 1
	mask = Rules.collect(level, tile, mask)
	_route.append(tile)
	if tile == level["finish"]:
		status = "cleared"
		cleared.emit()
	elif moves == level["limit"]:
		status = "spent"
	else:
		status = "ready"
	_update()
	return true


func _update() -> void:
	changed.emit()
	queue_redraw()


func _grid_rect() -> Rect2:
	var dimensions := Vector2(level["width"], level["height"])
	var cell := floorf(minf((size.x - 18.0) / dimensions.x, (size.y - 14.0) / dimensions.y))
	var board := dimensions * maxf(cell, 1.0)
	return Rect2((size - board) * 0.5, board)


func _gui_input(event: InputEvent) -> void:
	if level.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		var grid := _grid_rect()
		if grid.has_point(event.position):
			var cell := grid.size.x / float(level["width"])
			var point := Vector2i((event.position - grid.position) / cell)
			var direction := point - tile
			if direction in Rules.DIRECTIONS and move(direction):
				Sfx.play("click", 0.95, -1.5)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and not event.is_command_or_control_pressed():
		var direction: Vector2i = {
			KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
			KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP, KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
		}.get(event.keycode, Vector2i.ZERO)
		if direction != Vector2i.ZERO:
			move(direction)
			accept_event()
		elif event.keycode == KEY_R:
			reset_run()
			accept_event()


func _draw() -> void:
	if level.is_empty():
		return
	var grid := _grid_rect()
	var cell := grid.size.x / float(level["width"])
	for y in level["height"]:
		for x in level["width"]:
			var position_in_grid := Vector2(x, y) * cell + grid.position
			var rect := Rect2(position_in_grid + Vector2(2, 2), Vector2.ONE * (cell - 4.0))
			var wall: bool = level["rows"][y][x] == "#"
			draw_rect(rect, Color("1a2a31"))
			if wall:
				_draw_sprite("barrier", rect.get_center(), rect.size.x)
			else:
				_draw_sprite("floor", rect.get_center(), rect.size.x)
				if Vector2i(x, y) in _route:
					draw_rect(rect.grow(-2.0), Color(0.32, 0.84, 0.66, 0.18))
	var finish: Vector2i = level["finish"]
	var unlocked := Rules.can_exit(level, mask)
	_draw_sprite("exit_open" if unlocked else "exit_locked", _center(grid, finish, cell), cell * 0.95)
	for index in level["packets"].size():
		if (mask & (1 << index)) == 0:
			_draw_sprite("packet", _center(grid, level["packets"][index], cell), cell * 0.73)
	var player := _center(grid, tile, cell)
	_draw_sprite("courier", player, cell * (0.62 if tile == finish else 0.92))
	if has_focus():
		draw_rect(grid.grow(3), Color(ACCENT, 0.65), false, 1.0)


func _center(grid: Rect2, point: Vector2i, cell: float) -> Vector2:
	return grid.position + (Vector2(point) + Vector2(0.5, 0.5)) * cell


func _draw_sprite(id: String, center: Vector2, pixels: float) -> void:
	var texture := _sprites.get(id) as Texture2D
	if texture != null:
		var extent := Vector2.ONE * pixels
		draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false)
