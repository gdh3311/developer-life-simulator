extends VBoxContainer
## DevIDE: edits the real files of the company repo. Ctrl+S saves to disk.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DEFAULT_FILE := "README.md"

var desktop: Control
var _tree: Tree
var _code: CodeEdit
var _tab: Label
var _status: Label
var _current := ""
var _buffers := {}  # path -> unsaved text of files not currently open
var _saved_text := ""  # current file as last loaded/saved
var _loading := false
var _studio_save: Button
var _studio_preview: Button


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	_tree = Tree.new()
	_tree.custom_minimum_size.x = 200
	_tree.hide_root = true
	_tree.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG0, 0, Color(0, 0, 0, 0), 6))
	_tree.item_selected.connect(_on_tree_selected)
	split.add_child(_tree)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	split.add_child(right)
	var tab_bar := PanelContainer.new()
	tab_bar.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG2, 0, Color(0, 0, 0, 0), 7))
	_tab = UITheme.label("", 13, Color("c9cfd9"))
	_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tab_row := UITheme.hbox(6)
	tab_row.add_child(_tab)
	_studio_save = UITheme.button(Game.L("저장", "Save"))
	_studio_save.pressed.connect(save)
	tab_row.add_child(_studio_save)
	_studio_preview = UITheme.button(Game.L("TaskBoard로 돌아가기", "Back to TaskBoard"))
	_studio_preview.pressed.connect(func() -> void:
		if desktop != null and not _is_dirty():
			desktop.open_resource("tasks", "products"))
	tab_row.add_child(_studio_preview)
	tab_bar.add_child(tab_row)
	right.add_child(tab_bar)

	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.highlight_current_line = true
	_code.indent_size = 2
	_code.indent_use_spaces = true
	_code.auto_brace_completion_enabled = true
	_code.syntax_highlighter = ts_highlighter()
	_code.add_theme_font_override("font", UITheme.font(true))
	_code.add_theme_font_size_override("font_size", 14)
	_code.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG1, 0, Color(0, 0, 0, 0), 8))
	_code.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_code.add_theme_color_override("font_color", Color("d4d8de"))
	_code.add_theme_color_override("current_line_color", Color(1, 1, 1, 0.04))
	_code.add_theme_color_override("line_number_color", Color("4b5263"))
	_code.text_changed.connect(_on_text_changed)
	_code.gui_input.connect(_on_code_input)
	right.add_child(_build_find_bar())
	right.add_child(_code)

	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", UITheme.box(Color("1d4ed8"), 0, Color(0, 0, 0, 0), 3))
	_status = UITheme.label("", 11, Color("e6ecff"))
	status.add_child(_status)
	add_child(status)

	Workspace.repo_changed.connect(_on_repo_changed)
	_reload_tree()
	open_file(DEFAULT_FILE)


## Studio drafts (outside the Git checkout): Packet Run and the Moonlight page.
func _studio_for(path: String) -> Node:
	if path == ArcadeStudio.SOURCE:
		return ArcadeStudio
	if path == PageStudio.SOURCE:
		return PageStudio
	return null


func open_file(path: String) -> void:
	var studio_node := _studio_for(path)
	if studio_node != null and not studio_node.has_source():
		return
	if _current != "" and _is_dirty():
		_buffers[_current] = _code.text
	_current = path
	_saved_text = studio_node.read_source() if studio_node != null else Workspace.read_file(path)
	_set_text(_buffers.get(path, _saved_text))
	_code.clear_undo_history()
	_update_labels()
	if studio_node != null:
		_reload_tree()
		_code.grab_focus()
		return
	var resolved := Workspace.resolve(path)
	if resolved != "" and FileAccess.file_exists(resolved):
		Game.emit_event("code_viewed", {"path": path})


func save() -> void:
	if _current == "":
		return
	var studio_node := _studio_for(_current)
	var studio := studio_node != null
	var saved: bool = studio_node.write_source(_code.text) if studio else Workspace.write_file(_current, _code.text)
	if saved:
		_saved_text = _code.text
		_buffers.erase(_current)
		_update_labels()
		if not studio:
			Game.emit_event("file_saved", {"path": _current})
			Workspace.refresh()
	elif studio:
		_status.text = Game.L("작업 파일을 저장하지 못했습니다.", "Could not save the draft file.")


func _is_dirty() -> bool:
	return _code.text != _saved_text


func _set_text(text: String) -> void:
	_loading = true
	var caret := _code.get_caret_line()
	_code.text = text
	_code.set_caret_line(mini(caret, _code.get_line_count() - 1))
	_loading = false


func _on_text_changed() -> void:
	if not _loading:
		_update_labels()


func _on_code_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_S and key.is_command_or_control_pressed():
		save()
		_code.accept_event()
	elif key.keycode == KEY_F and key.is_command_or_control_pressed():
		_open_find()
		_code.accept_event()
	elif key.keycode == KEY_ESCAPE and _find_bar.visible:
		_find_bar.visible = false


# --- Find (Ctrl+F) ---------------------------------------------------------------

var _find_bar: PanelContainer
var _find_edit: LineEdit
var _find_count: Label


func _build_find_bar() -> Control:
	_find_bar = PanelContainer.new()
	_find_bar.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG2, 0, Color(0, 0, 0, 0), 6))
	_find_bar.visible = false
	var row := UITheme.hbox(8)
	row.add_child(UITheme.label(Game.L("찾기", "Find"), 12, UITheme.MUTED))
	_find_edit = LineEdit.new()
	_find_edit.custom_minimum_size.x = 260
	_find_edit.placeholder_text = Game.L("검색어 · Enter 다음 · Shift+Enter 이전 · Esc 닫기", "Search · Enter next · Shift+Enter previous · Esc close")
	_find_edit.text_changed.connect(func(_t: String) -> void: _find(true, false))
	_find_edit.text_submitted.connect(func(_t: String) -> void: _find(false, Input.is_key_pressed(KEY_SHIFT)))
	_find_edit.gui_input.connect(func(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k != null and k.pressed and k.keycode == KEY_ESCAPE:
			_find_bar.visible = false
			_code.set_search_text("")
			_code.grab_focus())
	row.add_child(_find_edit)
	_find_count = UITheme.label("", 12, UITheme.TEXT2)
	row.add_child(_find_count)
	_find_bar.add_child(row)
	return _find_bar


func _open_find() -> void:
	_find_bar.visible = true
	var sel := _code.get_selected_text()
	if sel != "" and not "
" in sel:
		_find_edit.text = sel
	_find_edit.grab_focus()
	_find_edit.select_all()
	_find(true, false)


## Highlights every match and moves the caret to the next (or previous) one.
func _find(from_start: bool, backwards: bool) -> void:
	var q := _find_edit.text
	_code.set_search_text(q)
	_code.queue_redraw()
	if q == "":
		_find_count.text = ""
		return
	var count := _code.text.countn(q)
	_find_count.text = Game.L("%d개", "%d found") % count
	if count == 0:
		return
	var line := 0 if from_start else _code.get_caret_line()
	var col := 0 if from_start else _code.get_caret_column()
	var flags := TextEdit.SEARCH_BACKWARDS if backwards else 0
	if backwards:
		col = maxi(0, col - q.length() - 1)
	var hit := _code.search(q, flags, line, col)
	if hit.x == -1:
		return
	_code.set_caret_line(hit.y)
	_code.set_caret_column(hit.x + (0 if backwards else q.length()))
	_code.select(hit.y, hit.x, hit.y, hit.x + q.length())
	_code.center_viewport_to_caret()


func _update_labels() -> void:
	var dirty := _is_dirty()
	var studio := _studio_for(_current) != null
	_studio_save.visible = studio
	_studio_save.disabled = not dirty
	_studio_preview.visible = studio and desktop != null
	_studio_preview.disabled = dirty
	_studio_preview.tooltip_text = Game.L("저장한 코드로 제품 업무의 자동 테스트를 실행하세요.", "Run the product ticket's automated tests on the saved source.")
	_tab.text = "  %s%s" % [_current.get_file(), "  ●" if dirty else ""]
	var conflict := "<<<<<<<" in _code.text or ">>>>>>>" in _code.text
	_status.text = "  ⎇ %s   ·   %s   ·   %s   ·   %s%s" % [
		"Studio" if studio else Workspace.branch, _current, Game.L("수정됨", "modified") if dirty else Game.L("저장됨", "saved"), Game.L("Ctrl+S 저장", "Ctrl+S to save"),
		Game.L("   ·   ⚠ 충돌 표시(<<<<<<< >>>>>>>)가 남아 있습니다", "   ·   ⚠ conflict markers (<<<<<<< >>>>>>>) remain") if conflict else ""]
	_status.get_parent().add_theme_stylebox_override("panel", UITheme.box(Color("b45309") if conflict else Color("1d4ed8"), 0, Color(0, 0, 0, 0), 3))


## Branch switches etc. change files on disk: reload the open file unless it has unsaved edits.
func _on_repo_changed() -> void:
	_reload_tree()
	if _current != "" and _studio_for(_current) == null:
		var disk := Workspace.read_file(_current)
		if disk != _saved_text and not _is_dirty():
			_set_text(disk)
		_saved_text = disk
	_update_labels()


func _reload_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var top := _tree.create_item(root)
	top.set_text(0, "commerce-api")
	top.set_selectable(0, false)
	var folders := {"": top}
	var files := Workspace.list_files()
	files.sort()
	for path in files:
		var parent := _ensure_folder(folders, String(path).get_base_dir())
		var item := _tree.create_item(parent)
		item.set_text(0, String(path).get_file())
		item.set_metadata(0, path)
		if path == _current:
			item.select(0)
	var drafts := [ArcadeStudio, PageStudio].filter(func(s: Node) -> bool: return s.has_source())
	if not drafts.is_empty():
		var studio := _tree.create_item(root)
		studio.set_text(0, "NEXORA Studio")
		studio.set_selectable(0, false)
		for s in drafts:
			var source := _tree.create_item(studio)
			source.set_text(0, String(s.SOURCE).get_file())
			source.set_metadata(0, s.SOURCE)
			if _current == s.SOURCE:
				source.select(0)


func _ensure_folder(folders: Dictionary, dir: String) -> TreeItem:
	if folders.has(dir):
		return folders[dir]
	var parent := _ensure_folder(folders, dir.get_base_dir() if "/" in dir else "")
	var item := _tree.create_item(parent)
	item.set_text(0, dir.get_file())
	item.set_selectable(0, false)
	folders[dir] = item
	return item


func _on_tree_selected() -> void:
	var item := _tree.get_selected()
	if item == null or item.get_metadata(0) == null:
		return
	var path: String = item.get_metadata(0)
	if path != _current:
		open_file(path)


static func ts_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color("d19a66")
	h.symbol_color = Color("abb2bf")
	h.function_color = Color("61afef")
	h.member_variable_color = Color("e06c75")
	for k in ["type", "export", "function", "return", "const", "let", "if", "else", "async", "await",
			"import", "from", "new", "throw", "null", "undefined", "true", "false", "for", "of", "in"]:
		h.add_keyword_color(k, Color("c678dd"))
	for k in ["string", "number", "boolean", "void"]:
		h.add_keyword_color(k, Color("e5c07b"))
	h.add_color_region("\"", "\"", Color("98c379"))
	h.add_color_region("'", "'", Color("98c379"))
	h.add_color_region("`", "`", Color("98c379"))
	h.add_color_region("//", "", Color("5c6370"), true)
	h.add_color_region("/*", "*/", Color("5c6370"))
	return h
