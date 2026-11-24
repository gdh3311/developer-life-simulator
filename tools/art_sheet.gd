extends SceneTree
## Dev tool: renders every studio illustration and desk item through Godot's own SVG renderer
## onto one contact sheet, so art can be reviewed exactly as the game draws it.
##   godot --path . --script res://tools/art_sheet.gd -- <output.png>

const FOLDERS := ["res://content/web/studio/art", "res://content/desk"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://art_sheet.png"
	root.size = Vector2i(1500, 1000)
	var bg := ColorRect.new()
	bg.color = Color("1c2344")
	bg.size = Vector2(1500, 1000)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(16, 16)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for folder in FOLDERS:
		for f in DirAccess.get_files_at(folder):
			if not f.ends_with(".svg"):
				continue
			var cell := VBoxContainer.new()
			var pic := TextureRect.new()
			pic.texture = load(folder.path_join(f)) as Texture2D
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(270, 150)
			cell.add_child(pic)
			var name := Label.new()
			name.text = f
			name.add_theme_font_size_override("font_size", 11)
			cell.add_child(name)
			grid.add_child(cell)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("ART_SHEET: ", ProjectSettings.globalize_path(out))
	quit()
