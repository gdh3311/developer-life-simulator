extends PanelContainer
## Terminal app: runs real git and the test runner inside the company repo.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const HELP_EN := """[color=#9aa4b5]Commands[/color]
  git <...>        git commands (status, switch -c, add, commit -m, push, pull, log, blame, diff ...)
  npm test         run the tests (or just: test)
  ls [path]        list files
  cat <file>       print a file
  touch <file>     create an empty file      mkdir <dir>   create a folder
  pwd / whoami / clear / help
[color=#6f7a8c]Use ↑/↓ to recall earlier commands.[/color]"""
const HELP := """[color=#9aa4b5]명령어[/color]
  git <...>        Git 명령 (status, switch -c, add, commit -m, push, pull, log, blame, diff ...)
  npm test         테스트 실행 (test 로 줄여 써도 됨)
  ls [경로]         파일 목록
  cat <파일>        파일 내용 보기
  touch <파일>      빈 파일 만들기        mkdir <폴더>   폴더 만들기
  pwd / whoami / clear / help
[color=#6f7a8c]↑/↓ 로 이전 명령을 불러올 수 있어요.[/color]"""

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

	_print("[color=#7c8698]%s[/color]" % Game.L("WORKSTATION OS terminal — 'help' 를 입력해 보세요.", "WORKSTATION OS terminal — type 'help' to get started."))
	_update_prompt()
	Workspace.repo_changed.connect(_update_prompt)
	_input.call_deferred("grab_focus")


func _update_prompt() -> void:
	_prompt.text = "newhire@nexora:~/commerce-api (%s)$" % Workspace.branch


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
		_print("[color=#e06c75]%s[/color]" % Game.L("워크스페이스가 준비되지 않았습니다.", "The workspace isn't ready."))
		return
	var cmd := argv[0]
	Game.emit_event("cmd", {"argv": Array(argv)})
	match cmd:
		"help":
			_print(Game.L(HELP, HELP_EN))
		"clear":
			_out.clear()
		"pwd":
			_print(Workspace.V_REPO)
		"whoami":
			_print("newhire  (%s · %s · NEXORA)" % [Game.pname(), Game.rank_name()])
		"cd":
			_print("[color=#7c8698]%s[/color]" % Game.L("이 터미널은 ~/commerce-api 저장소에서 동작합니다.", "This terminal works inside the ~/commerce-api repository."))
		"ls":
			_ls(argv[1] if argv.size() > 1 else "")
		"cat":
			_cat(argv[1] if argv.size() > 1 else "")
		"touch", "mkdir":
			await _make(cmd, argv[1] if argv.size() > 1 else "")
		"git":
			var args: Array = Array(argv.slice(1)).map(func(a: String) -> String:
				return Workspace.devirtualize(a) if a.begins_with(Workspace.V_REPO) or a.begins_with("~/") else a)
			var why := Workspace.check_git_args(args)
			if why != "":
				_print("[color=#f5a524]%s[/color]" % _esc(why))
				return
			var r := await Workspace.git(args)
			var text := String(r["out"]) + String(r["err"])
			if r["timed_out"]:
				text += "\n(시간 초과로 중단됨)"
			text = text.strip_edges(false, true)
			if text != "":
				_print(_esc(text))
			if "problem with the editor" in text or "Aborting commit due to empty" in text:
				_print("[color=#7c8698]%s[/color]" % Game.L("팁: 커밋 메시지는 -m 으로 바로 적어 주세요.  git commit -m \"fix: ...\"", "Tip: write the commit message with -m.  git commit -m \"fix: ...\""))
			if "Please tell me who you are" in text or "Author identity unknown" in text:
				_print("[color=#f5a524]%s[/color]" % Game.L("팁: 먼저 내 정보를 설정하세요.  git config user.name \"이름\"  /  git config user.email \"me@nexora.dev\"", "Tip: set your identity first.  git config user.name \"Name\"  /  git config user.email \"me@nexora.dev\""))
		"test", "npm":
			if cmd == "npm" and (argv.size() < 2 or argv[1] != "test"):
				_print(Game.L("이 터미널에서는 npm test 만 지원합니다.", "Only npm test is supported here."))
			else:
				await _run_tests()
		_:
			_print("[color=#e06c75]command not found:[/color] %s  [color=#7c8698](help)[/color]" % _esc(cmd))


func _ls(rel: String) -> void:
	var dir := Workspace.resolve(rel)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		_print(Game.L("ls: 경로를 찾을 수 없습니다: ", "ls: no such path: ") + _esc(rel))
		return
	var items: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if d != ".git":
			items.append("[color=#61afef]%s/[/color]" % d)
	for f in DirAccess.get_files_at(dir):
		items.append(_esc(f))
	_print("  ".join(items))


func _make(cmd: String, rel: String) -> void:
	var p := Workspace.resolve(rel)
	if rel == "" or p == "" or p == Workspace.repo:
		_print(Game.L("%s: 경로를 입력하세요.", "%s: give a path.") % cmd)
		return
	if cmd == "mkdir":
		DirAccess.make_dir_recursive_absolute(p)
	elif not FileAccess.file_exists(p):
		Workspace.write_file(rel, "")
	await Workspace.refresh()


func _cat(rel: String) -> void:
	var p := Workspace.resolve(rel)
	if rel == "" or p == "" or not FileAccess.file_exists(p):
		_print(Game.L("cat: 파일을 찾을 수 없습니다: ", "cat: no such file: ") + _esc(rel))
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
	_print("[color=%s]%s[/color]" % [color, Game.L("통과 %d · 실패 %d", "%d passed · %d failed") % [r["passed"], r["failed"]]])


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
