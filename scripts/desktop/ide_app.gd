extends VBoxContainer
## DevIDE: edits the real files of the company repo. Ctrl+S saves to disk.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DEFAULT_FILE := "README.md"

var _tree: Tree
var _code: CodeEdit
var _tab: Label
var _status: Label
var _current := ""
var _buffers := {}  # path -> unsaved text of files not currently open
var _saved_text := ""  # current file as last loaded/saved
var _loading := false


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
	tab_bar.add_child(_tab)
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
	right.add_child(_code)

	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", UITheme.box(Color("1d4ed8"), 0, Color(0, 0, 0, 0), 3))
	_status = UITheme.label("", 11, Color("e6ecff"))
	status.add_child(_status)
	add_child(status)

	Workspace.repo_changed.connect(_on_repo_changed)
	_reload_tree()
	open_file(DEFAULT_FILE)


func open_file(path: String) -> void:
	if _current != "" and _is_dirty():
		_buffers[_current] = _code.text
	_current = path
	_saved_text = Workspace.read_file(path)
	_set_text(_buffers.get(path, _saved_text))
	_code.clear_undo_history()
	_update_labels()


func save() -> void:
	if _current == "":
		return
	if Workspace.write_file(_current, _code.text):
		_saved_text = _code.text
		_buffers.erase(_current)
		_update_labels()
		Game.emit_event("file_saved", {"path": _current})
		Workspace.refresh()


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
	if key != null and key.pressed and key.keycode == KEY_S and key.is_command_or_control_pressed():
		save()
		_code.accept_event()


func _update_labels() -> void:
	var dirty := _is_dirty()
	_tab.text = "  %s%s" % [_current.get_file(), "  ●" if dirty else ""]
	var conflict := "<<<<<<<" in _code.text or ">>>>>>>" in _code.text
	_status.text = "  ⎇ %s   ·   %s   ·   %s   ·   %s%s" % [
		Workspace.branch, _current, Game.L("수정됨", "modified") if dirty else Game.L("저장됨", "saved"), Game.L("Ctrl+S 저장", "Ctrl+S to save"),
		Game.L("   ·   ⚠ 충돌 표시(<<<<<<< >>>>>>>)가 남아 있습니다", "   ·   ⚠ conflict markers (<<<<<<< >>>>>>>) remain") if conflict else ""]
	_status.get_parent().add_theme_stylebox_override("panel", UITheme.box(Color("b45309") if conflict else Color("1d4ed8"), 0, Color(0, 0, 0, 0), 3))


## Branch switches etc. change files on disk: reload the open file unless it has unsaved edits.
func _on_repo_changed() -> void:
	_reload_tree()
	if _current != "":
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
