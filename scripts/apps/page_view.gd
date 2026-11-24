extends VBoxContainer
## moonlight.shop — the released pre-order page, rendered from the build PageStudio approved.
## Everything shown (prices, time-left wording, whether a button works) comes from the player's code.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Art := preload("res://scripts/ui/illustrations.gd")
const Studio := preload("res://scripts/services/page_studio.gd")
const THEMES := {
	"night": {"bg": Color("141a33"), "bg2": Color("232b52"), "text": Color("f2f0ff"), "muted": Color("b8b5d6"), "accent": Color("f4c95d"), "card": Color("1c2344")},
	"dawn": {"bg": Color("ffe2cf"), "bg2": Color("ffc9b0"), "text": Color("3a2420"), "muted": Color("7a5a50"), "accent": Color("e0785a"), "card": Color("fff3ea")},
	"paper": {"bg": Color("f5f1e8"), "bg2": Color("e9e2d2"), "text": Color("2b2b2b"), "muted": Color("6b665c"), "accent": Color("3b5bdb"), "card": Color("ffffff")},
}

var build := {}
var minutes_left := 125
var cart: Array = []
var stock: Array = []
var _countdown: Label
var _cart_label: Label
var _grid: GridContainer
var _hero_row: BoxContainer
var _buttons: Array = []
var _cart_list: VBoxContainer
var _slider: HSlider


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	PageStudio.changed.connect(_load)
	resized.connect(_fit_width)
	_load()


func _load() -> void:
	var release: Dictionary = PageStudio.release()
	if release.get("revision", "") == build.get("revision", "x") and not build.is_empty():
		return
	build = release
	cart.clear()
	stock.clear()
	UITheme.clear(self)
	if build.is_empty():
		var empty := UITheme.vbox(8)
		empty.add_child(UITheme.bold("404", 40, UITheme.MUTED))
		empty.add_child(UITheme.wrap(Game.L("아직 공개된 페이지가 없습니다. TaskBoard의 제품 개발에서 페이지를 만들고 공개하세요.", "Nothing is published here yet. Build and release the page from TaskBoard's product work."), 14, UITheme.TEXT2))
		add_child(UITheme.margin(empty, 24))
		return
	for p in build["page"]["products"]:
		stock.append(int(p["stock"]))
	_build_page()


func _theme() -> Dictionary:
	return THEMES.get(String(build["page"]["theme"]), THEMES["night"])


func _build_page() -> void:
	var th := _theme()
	var page: Dictionary = build["page"]
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UITheme.box(th["bg"], 0, Color(0, 0, 0, 0), 0))
	add_child(bg)
	var v := UITheme.vbox(14)
	bg.add_child(UITheme.margin(v, 18))
	# Header
	var top := UITheme.hbox(8)
	top.add_child(Art.icon_view(Art.website("moonlight"), 29))
	var brand := UITheme.wrap(String(page["title"]), 18, th["text"])
	brand.add_theme_font_override("font", UITheme.font(false, true))
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(brand)
	_cart_label = UITheme.label("", 13, th["muted"])
	top.add_child(_cart_label)
	v.add_child(top)
	# Hero
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", UITheme.box(th["bg2"], 12, Color.TRANSPARENT, 16))
	_hero_row = BoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 14)
	hero.add_child(_hero_row)
	var hv := UITheme.vbox(8)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.size_flags_stretch_ratio = 1.3
	_hero_row.add_child(hv)
	var headline := UITheme.wrap(String(page["headline"]), 24, th["text"])
	headline.add_theme_font_override("font", UITheme.font(false, true))
	hv.add_child(headline)
	if String(page.get("sub", "")) != "":
		hv.add_child(UITheme.wrap(String(page["sub"]), 13, th["muted"]))
	_countdown = UITheme.bold("", 20, th["accent"])
	hv.add_child(_countdown)
	var d: Dictionary = page["deadline"]
	hv.add_child(UITheme.wrap(Game.L("마감 %s (판매자 시간)", "Closes %s (seller time)") % String(d["local"]).replace("T", " "), 12, th["muted"]))
	var hero_photo := _photo("hero", 156)
	hero_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_row.add_child(hero_photo)
	v.add_child(hero)
	# Developer preview control (not part of the customer page).
	var dev := UITheme.hbox(8)
	dev.add_child(UITheme.label(Game.L("미리보기 · 남은 시간", "Preview · time left"), 11, th["muted"]))
	var slider := HSlider.new()
	_slider = slider
	slider.min_value = -5
	slider.max_value = 300
	slider.step = 1
	slider.value = minutes_left
	slider.custom_minimum_size.x = 92
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(x: float) -> void: set_minutes(int(x)))
	dev.add_child(slider)
	v.add_child(dev)
	# Products
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(_grid)
	_buttons.clear()
	var products: Array = page["products"]
	for i in products.size():
		_grid.add_child(_card(i, products[i], th))
	_cart_list = UITheme.vbox(4)
	v.add_child(_cart_list)
	_fit_width()
	_refresh()


func _fit_width() -> void:
	if not is_instance_valid(_grid) or not is_instance_valid(_hero_row):
		return
	var available := size.x - 36.0
	_hero_row.vertical = available < 530.0
	_grid.columns = 3 if available >= 600.0 else (2 if available >= 374.0 else 1)


func _photo(image_id: String, height: float) -> TextureRect:
	var photo := TextureRect.new()
	photo.texture = Art.product(image_id)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size.y = height
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return photo


func _card(i: int, p: Dictionary, th: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(th["card"], 12, Color(0, 0, 0, 0.08), 12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := UITheme.vbox(6)
	card.add_child(cv)
	var art := _photo(String(p["image"]), 136)
	art.tooltip_text = String(p["alt"]) if String(p["alt"]) != "" else Game.L("(대체 텍스트 없음)", "(no alt text)")
	cv.add_child(art)
	var product_name := UITheme.wrap(String(p["name"]), 15, th["text"])
	product_name.add_theme_font_override("font", UITheme.font(false, true))
	cv.add_child(product_name)
	cv.add_child(UITheme.label(Studio.price_text(build, int(p["price"])), 14, th["accent"]))
	var stock_label := UITheme.label("", 11, th["muted"])
	stock_label.name = "Stock"
	cv.add_child(stock_label)
	var b := Button.new()
	b.text = String(build["page"]["cta"])
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 34
	b.add_theme_stylebox_override("normal", UITheme.box(th["accent"], 8, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("hover", UITheme.box(Color(th["accent"]).lightened(0.12), 8, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("disabled", UITheme.box(Color(th["muted"]).darkened(0.1), 8, Color(0, 0, 0, 0), 6))
	b.add_theme_color_override("font_color", Color(th["bg"]))
	b.add_theme_color_override("font_disabled_color", Color(th["bg"]).lightened(0.2))
	b.pressed.connect(reserve.bind(i))
	cv.add_child(b)
	_buttons.append([b, stock_label])
	return card


func set_minutes(m: int) -> void:
	minutes_left = m
	if _slider != null and int(_slider.value) != m:
		_slider.set_value_no_signal(m)
	_refresh()


## A customer presses the pre-order button (also used by tests).
func reserve(i: int) -> bool:
	if build.is_empty() or i < 0 or i >= stock.size() or not Studio.can_reserve(build, stock[i], minutes_left):
		return false
	stock[i] -= 1
	cart.append(i)
	Sfx.play("purchase", 1.1, -8.0)
	_refresh()
	return true


func button_enabled(i: int) -> bool:
	return not _buttons[i][0].disabled


func countdown_text() -> String:
	return _countdown.text


func _refresh() -> void:
	if build.is_empty() or _countdown == null:
		return
	var th := _theme()
	_countdown.text = Studio.label_for(build, minutes_left)
	for i in _buttons.size():
		var b: Button = _buttons[i][0]
		var s: Label = _buttons[i][1]
		b.disabled = not Studio.can_reserve(build, stock[i], minutes_left)
		s.text = Game.L("재고 %d개", "%d in stock") % stock[i] if stock[i] > 0 else Game.L("품절", "Sold out")
	_cart_label.text = Game.L("장바구니 %d", "Cart %d") % cart.size()
	UITheme.clear(_cart_list)
	if not cart.is_empty():
		_cart_list.add_child(UITheme.label(Game.L("예약한 상품", "Your pre-orders"), 12, th["muted"]))
		for i in cart:
			var p: Dictionary = build["page"]["products"][i]
			_cart_list.add_child(UITheme.label("· %s  %s" % [String(p["name"]), Studio.price_text(build, int(p["price"]))], 13, th["text"]))
