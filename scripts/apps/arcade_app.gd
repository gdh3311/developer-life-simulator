extends VBoxContainer
## The player-facing catalog for released games.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Rules := preload("res://scripts/services/arcade_rules.gd")
const Board := preload("res://scripts/apps/arcade_board.gd")
const MINT := Color("a5ebd8")
const GOLD := Color("f4ce84")

var _mode := "sample"
var _release_revision := ""
var _modes := {}
var _board: Control
var _title: Label
var _intro: Label
var _remaining: Label
var _inventory: Label
var _run_status: Label
var _undo: Button


func _ready() -> void:
	add_theme_constant_override("separation", 11)
	add_child(UITheme.bold("NEXORA Arcade", 26, MINT))
	var previews := HFlowContainer.new()
	previews.add_theme_constant_override("h_separation", 6)
	previews.add_theme_constant_override("v_separation", 6)
	for pair in [["sample", Game.L("팀 기본판", "Team edition")], ["release", Game.L("최신 배포판", "Latest release")]]:
		var button := _action(pair[1])
		button.toggle_mode = true
		button.pressed.connect(_select_product.bind(pair[0]))
		previews.add_child(button)
		_modes[pair[0]] = button
	add_child(previews)
	var workspace := HFlowContainer.new()
	workspace.add_theme_constant_override("h_separation", 12)
	workspace.add_theme_constant_override("v_separation", 12)
	add_child(workspace)
	workspace.add_child(_build_player())
	workspace.add_child(_build_guide())
	ArcadeStudio.changed.connect(_refresh_release)
	_select_product("sample")
	_refresh_release()
	_board.grab_focus.call_deferred()


func _action(text: String) -> Button:
	var button := UITheme.button(text)
	button.custom_minimum_size.y = 34
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", UITheme.box(Color.TRANSPARENT, 6, MINT))
	button.add_theme_stylebox_override("pressed", UITheme.box(Color("245148"), 7, Color("458777"), 7))
	return button


func _build_player() -> PanelContainer:
	var panel := UITheme.panel(Color("121f25"), 9, 12, Color("355560"))
	panel.custom_minimum_size.x = 275
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UITheme.vbox(8)
	panel.add_child(column)
	_title = UITheme.wrap("", 22, UITheme.TEXT)
	_title.add_theme_font_override("font", UITheme.font(false, true))
	column.add_child(_title)
	_intro = UITheme.wrap("", 13, UITheme.TEXT2)
	column.add_child(_intro)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 7)
	stats.add_theme_constant_override("v_separation", 7)
	_remaining = UITheme.bold("", 13, MINT)
	_inventory = UITheme.bold("", 13, GOLD)
	_remaining.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inventory.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.add_child(_remaining)
	stats.add_child(_inventory)
	column.add_child(stats)
	_board = Board.new()
	_board.changed.connect(_refresh_board)
	_board.cleared.connect(func() -> void: Sfx.play("tests_ok"))
	column.add_child(_board)
	_run_status = UITheme.wrap("", 12, UITheme.TEXT2)
	_run_status.custom_minimum_size.y = 24
	column.add_child(_run_status)
	var restart := _action(Game.L("다시 시작", "Restart"))
	restart.pressed.connect(func() -> void:
		_board.reset_run()
		_board.grab_focus())
	stats.add_child(restart)
	_undo = _action(Game.L("되돌리기", "Undo move"))
	_undo.pressed.connect(func() -> void:
		_board.undo()
		_board.grab_focus())
	stats.add_child(_undo)
	return panel


func _build_guide() -> PanelContainer:
	var panel := UITheme.panel(Color("1c2730"), 9, 13, Color("394653"))
	panel.custom_minimum_size.x = 208
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := UITheme.vbox(9)
	panel.add_child(column)
	column.add_child(UITheme.bold(Game.L("조작과 목표", "Controls and goal"), 17))
	column.add_child(UITheme.wrap(Game.L("방향키 또는 인접한 칸을 클릭해 이동하세요.", "Use the arrow keys or click an adjacent tile."), 13, UITheme.TEXT2))
	column.add_child(UITheme.wrap(Game.L("노란 패킷을 모두 모으면 출구가 열립니다.", "Collect all gold packets to unlock the exit."), 13, GOLD))
	column.add_child(UITheme.wrap(Game.L("이동 횟수를 다 쓰면 되돌리거나 다시 시작할 수 있습니다.", "Undo a move or restart if you run out of moves."), 13, UITheme.TEXT2))
	return panel


func _select_product(mode: String) -> void:
	var artifact: Dictionary = ArcadeStudio.release() if mode == "release" else Rules.SAMPLE
	if artifact.is_empty():
		return
	_mode = mode
	_board.load_level(artifact)
	_title.text = _board.level["title"]
	_intro.text = Game.L("노란 패킷을 모아 출구까지 이동하세요.", "Collect the gold packets and reach the exit.") if mode == "sample" else _board.level["intro"]
	_intro.visible = not _intro.text.is_empty()
	for key in _modes:
		_modes[key].set_pressed_no_signal(key == _mode)


func _refresh_release() -> void:
	var release := ArcadeStudio.release()
	_modes["release"].disabled = release.is_empty()
	var revision: String = release.get("revision", "")
	if revision != _release_revision:
		_release_revision = revision
		_select_product("sample" if release.is_empty() else "release")


func _refresh_board() -> void:
	_remaining.text = Game.L("이동 %d 남음", "%d moves left") % (_board.level["limit"] - _board.moves)
	_inventory.text = Game.L("패킷 %d / %d", "Packets %d / %d") % [Rules.count(_board.mask), _board.level["packets"].size()]
	_undo.disabled = _board.moves == 0
	match _board.status:
		"cleared": _run_status.text = Game.L("출구 도착! %d번 이동으로 완주했어요.", "You reached the exit in %d moves.") % _board.moves
		"spent": _run_status.text = Game.L("이동 횟수를 다 썼어요. 되돌리거나 다시 시작할 수 있습니다.", "Out of moves. Undo a move or restart.")
		"wall": _run_status.text = Game.L("막힌 통로예요. 이동은 차감되지 않았습니다.", "That tile is blocked. No move spent.")
		"locked": _run_status.text = Game.L("출구가 잠겨 있어요. 남은 패킷을 확인하세요.", "The exit is locked. Check the remaining packets.")
		_: _run_status.text = Game.L("방향키 또는 인접 칸 클릭 · R 다시 시작", "Arrow keys or click a neighbor · R to restart")
