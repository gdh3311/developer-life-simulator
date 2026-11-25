extends RefCounted
## Atlas regions for the original raster artwork used by Relay and its products.

const WEB := "res://content/web/art/relay-site-icons.png"
const ARCADE := "res://content/web/art/packet-run-sprites.png"
const MOONLIGHT := "res://content/web/art/moonlight-products.png"
const WEB_ORDER := ["relay", "portal", "connectly", "news", "video", "lounge", "shop", "arcade", "moonlight"]
## Sites added after the 3×3 icon sheet was painted use their own image file.
const WEB_EXTRA := {"atlas": "res://content/web/art/site-atlas.svg", "campaign": "res://content/web/art/site-campaign.svg"}
const ARCADE_ORDER := ["courier", "packet", "barrier", "exit_locked", "exit_open", "floor"]
const PRODUCT_ORDER := ["tea", "cup", "cookie", "candle", "jam", "hero"]

static var _textures := {}


static func website(id: String) -> Texture2D:
	if WEB_EXTRA.has(id):
		# Same shape as the sheet icons (an AtlasTexture), cached so every caller gets one instance.
		var key := "extra:" + id
		if not _textures.has(key):
			var image := load(WEB_EXTRA[id]) as Texture2D
			if image == null:
				return null
			var tile := AtlasTexture.new()
			tile.atlas = image
			tile.region = Rect2(Vector2.ZERO, image.get_size())
			_textures[key] = tile
		return _textures[key]
	var index := WEB_ORDER.find(id)
	if index < 0:
		return null
	var origin := Vector2(53 + (index % 3) * 396, 59 + floori(index / 3.0) * 394)
	return _texture(WEB, index, Vector2i(3, 3), Rect2(origin, Vector2(350, 354)))


static func arcade(id: String) -> Texture2D:
	var index := ARCADE_ORDER.find(id)
	if index < 0:
		return null
	var origin := Vector2(56 + (index % 3) * 502, 47 + floori(index / 3.0) * 508)
	return _texture(ARCADE, index, Vector2i(3, 2), Rect2(origin, Vector2.ONE * 424))


static func product(id: String) -> Texture2D:
	return _texture(MOONLIGHT, PRODUCT_ORDER.find(id), Vector2i(3, 2))


static func icon_view(texture: Texture2D, pixels: float) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.custom_minimum_size = Vector2.ONE * pixels
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return view


static func _texture(path: String, index: int, grid: Vector2i, region := Rect2()) -> Texture2D:
	if index < 0:
		return null
	var key := "%s:%d" % [path, index]
	if _textures.has(key):
		return _textures[key]
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var sheet := load(path) as Texture2D
	if sheet == null:
		return null
	if not region.has_area():
		var cell := (sheet.get_size() / Vector2(grid)).floor()
		var offset := Vector2(index % grid.x, floori(index / float(grid.x))) * cell
		region = Rect2(offset + Vector2(3, 3), cell - Vector2(6, 6))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	atlas.filter_clip = true
	_textures[key] = atlas
	return atlas
