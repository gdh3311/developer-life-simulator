extends RefCounted
## Shared grid rules for the playable board and the review's shortest-route check.

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SAMPLE := {
	"level": {"title": "Packet Run", "intro": "", "moveLimit": 16,
		"rows": ["S..#..", ".#.P..", ".#.#.E", "...#..", "#P...."]},
	"exits": [false, false, true],
}


static func unpack(build: Dictionary) -> Dictionary:
	var raw = build.get("level")
	var exits = build.get("exits")
	if not raw is Dictionary or not exits is Array:
		return {}
	var rows = raw.get("rows")
	var title = raw.get("title")
	var intro = raw.get("intro")
	var limit = raw.get("moveLimit")
	if not rows is Array or rows.size() < 4 or rows.size() > 8 or not rows[0] is String:
		return {}
	if not title is String or title.strip_edges().is_empty() or title.length() > 56 or not intro is String or intro.length() > 150:
		return {}
	if typeof(limit) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(limit)) or limit != floor(limit) or limit < 4 or limit > 32:
		return {}
	var width: int = rows[0].length()
	if width < 4 or width > 8:
		return {}
	var start := Vector2i(-1, -1)
	var finish := Vector2i(-1, -1)
	var packets: Array[Vector2i] = []
	var walls := 0
	for y in rows.size():
		if not rows[y] is String or rows[y].length() != width:
			return {}
		for x in width:
			var point := Vector2i(x, y)
			match rows[y][x]:
				"S":
					if start.x >= 0:
						return {}
					start = point
				"E":
					if finish.x >= 0:
						return {}
					finish = point
				"P": packets.append(point)
				"#": walls += 1
				".": pass
				_: return {}
	if start.x < 0 or finish.x < 0 or packets.size() > 8 or exits.size() != packets.size() + 1:
		return {}
	for entry in exits:
		if not entry is bool:
			return {}
	return {"rows": rows, "title": title, "intro": intro, "limit": int(limit),
		"width": width, "height": rows.size(), "start": start, "finish": finish,
		"packets": packets, "walls": walls, "exits": exits}


static func walkable(level: Dictionary, tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < level["width"] and tile.y < level["height"] and level["rows"][tile.y][tile.x] != "#"


static func collect(level: Dictionary, tile: Vector2i, mask: int) -> int:
	var index: int = level["packets"].find(tile)
	return mask | (1 << index) if index >= 0 else mask


static func count(mask: int) -> int:
	var total := 0
	while mask != 0:
		total += 1
		mask &= mask - 1
	return total


static func can_exit(level: Dictionary, mask: int) -> bool:
	return level["exits"][count(mask)]


static func shortest_route(level: Dictionary) -> int:
	# Each search state is the cell plus its collected packet set.
	var start: Vector2i = level["start"]
	var frontier: Array[Vector4i] = [Vector4i(start.x, start.y, 0, 0)]
	var seen := {Vector3i(start.x, start.y, 0): true}
	var index := 0
	while index < frontier.size():
		var state := frontier[index]
		index += 1
		for direction in DIRECTIONS:
			var tile: Vector2i = Vector2i(state.x, state.y) + direction
			if not walkable(level, tile):
				continue
			if tile == level["finish"]:
				if can_exit(level, state.z) and count(state.z) == level["packets"].size():
					return state.w + 1
				continue
			var mask := collect(level, tile, state.z)
			var key := Vector3i(tile.x, tile.y, mask)
			if not seen.has(key):
				seen[key] = true
				frontier.append(Vector4i(tile.x, tile.y, mask, state.w + 1))
	return -1
