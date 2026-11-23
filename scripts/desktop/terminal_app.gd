extends PanelContainer
## Terminal app: runs real git and the test runner inside the company repo.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const HELP := """[color=#9aa4b5]명령어[/color]
  git <...>        실제 Git 명령 (status, switch -c, add, commit -m, push, log ...)
  npm test         테스트 실행 (test 로 줄여 써도 됨)
  ls [경로]         파일 목록
  cat <파일>        파일 내용 보기
  pwd / clear / help"""

var _out: RichTextLabel
var _prompt: Label
var _input: LineEdit
var _history: Array[String] = []
var _history_pos := 0
var _busy := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color("0c0e12"), 0, Color(0, 0, 0, 0), 10))
	var v := VBoxContainer.new()
	add_child(v)

	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.add_theme_font_override("normal_font", UITheme.font(true))
	_out.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(_out)

	var row := HBoxContainer.new()
	_prompt = UITheme.label("", 14, Color("3ddc84"), true)
	row.add_child(_prompt)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.flat = true
	_input.add_theme_font_override("font", UITheme.font(true))
	_input.add_theme_font_size_override("font_size", 14)
	_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_key)
	row.add_child(_input)
	v.add_child(row)

	_print("[color=#7c8698]WORKSTATION OS terminal — 'help' 를 입력해 보세요.[/color]")
	_update_prompt()
	Workspace.repo_changed.connect(_update_prompt)
	_input.call_deferred("grab_focus")


func _update_prompt() -> void:
	_prompt.text = "~/commerce-api (%s) $" % Workspace.branch


func _print(bbcode: String) -> void:
	_out.append_text(bbcode + "\n")


static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


func _on_input_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_pos = maxi(_history_pos - 1, 0)
	elif key.keycode == KEY_DOWN:
		_history_pos = mini(_history_pos + 1, _history.size())
	else:
		return
	_input.text = _history[_history_pos] if _history_pos < _history.size() else ""
	_input.caret_column = _input.text.length()
	_input.accept_event()


func _on_submit(line: String) -> void:
	if _busy:
		return
	_input.clear()
	line = line.strip_edges()
	_print("[color=#3ddc84]$[/color] " + _esc(line))
	if line == "":
		return
	_history.append(line)
	_history_pos = _history.size()
	_busy = true
	_input.editable = false
	await _execute(tokenize(line))
	_busy = false
	_input.editable = true
	_input.grab_focus()


func _execute(argv: PackedStringArray) -> void:
	if not Workspace.is_ready:
		_print("[color=#e06c75]워크스페이스가 준비되지 않았습니다.[/color]")
		return
	var cmd := argv[0]
	match cmd:
		"help":
			_print(HELP)
		"clear":
			_out.clear()
		"pwd":
			_print(_esc(Workspace.repo))
		"ls":
			_ls(argv[1] if argv.size() > 1 else "")
		"cat":
			_cat(argv[1] if argv.size() > 1 else "")
		"git":
			var r := await Workspace.git(Array(argv.slice(1)))
			var text := String(r["out"]) + String(r["err"])
			if r["timed_out"]:
				text += "\n(시간 초과로 중단됨)"
			text = text.strip_edges(false, true)
			if text != "":
				_print(_esc(text))
		"test", "npm":
			if cmd == "npm" and (argv.size() < 2 or argv[1] != "test"):
				_print("이 터미널에서는 npm test 만 지원합니다.")
			else:
				await _run_tests()
		_:
			_print("[color=#e06c75]command not found:[/color] %s  [color=#7c8698](help 참고)[/color]" % _esc(cmd))


func _ls(rel: String) -> void:
	var dir := Workspace.resolve(rel)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		_print("ls: 경로를 찾을 수 없습니다: " + _esc(rel))
		return
	var items: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if d != ".git":
			items.append("[color=#61afef]%s/[/color]" % d)
	for f in DirAccess.get_files_at(dir):
		items.append(_esc(f))
	_print("  ".join(items))


func _cat(rel: String) -> void:
	var p := Workspace.resolve(rel)
	if rel == "" or p == "" or not FileAccess.file_exists(p):
		_print("cat: 파일을 찾을 수 없습니다: " + _esc(rel))
		return
	_print(_esc(FileAccess.get_file_as_string(p).strip_edges(false, true)))


func _run_tests() -> void:
	_print("[color=#7c8698]> node --test tests/[/color]")
	var r := await Workspace.run_tests()
	if r.has("error") and not r.has("tests"):
		_print("[color=#e06c75]%s[/color]" % _esc(r["error"]))
		return
	for t in r["tests"]:
		if t["ok"]:
			_print("  [color=#3ddc84]✓[/color] " + _esc(t["name"]))
		else:
			_print("  [color=#e06c75]✗ %s[/color]" % _esc(t["name"]))
			for d in t["detail"]:
				_print("      [color=#7c8698]%s[/color]" % _esc(d))
	if r["tests"].is_empty():
		_print(_esc(String(r["output"]).strip_edges()))
	if r.has("error"):
		_print("[color=#e06c75]%s[/color]" % _esc(r["error"]))
	var color := "#3ddc84" if r["ok"] else "#e06c75"
	_print("[color=%s]통과 %d · 실패 %d[/color]" % [color, r["passed"], r["failed"]])


## Splits a command line into arguments, honouring "double" and 'single' quotes.
static func tokenize(line: String) -> PackedStringArray:
	var args := PackedStringArray()
	var cur := ""
	var quote := ""
	var has_token := false
	for ch in line:
		if quote != "":
			if ch == quote:
				quote = ""
			else:
				cur += ch
		elif ch == "\"" or ch == "'":
			quote = ch
			has_token = true
		elif ch == " " or ch == "\t":
			if has_token or cur != "":
				args.append(cur)
			cur = ""
			has_token = false
		else:
			cur += ch
	if has_token or cur != "":
		args.append(cur)
	return args
