extends RefCounted
## Content builders for each in-game application.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

const IdeApp := preload("res://scripts/desktop/ide_app.gd")
const TerminalApp := preload("res://scripts/desktop/terminal_app.gd")


static func build(id: String) -> Control:
	match id:
		"ide":
			return IdeApp.new()
		"terminal":
			return TerminalApp.new()
		"chat":
			return _chat()
		"tasks":
			return _tasks()
		"wiki":
			return _wiki()
	return _placeholder("AICode 에이전트\n\nEarly Access에서 활성화됩니다.\nAI 없이도 모든 업무를 끝까지 진행할 수 있어요.")


# --- TeamChat ---------------------------------------------------------------

static func _chat() -> Control:
	var split := HSplitContainer.new()
	var list := ItemList.new()
	list.custom_minimum_size.x = 180
	list.add_theme_stylebox_override("panel", UITheme.box(Color("161a21"), 0, Color(0, 0, 0, 0), 6))
	for ch in ["# general", "# dev", "# qa", "Alex Kim · PM", "Mina Choi · QA", "Daniel Park · Senior", "Sophie Lee · Frontend"]:
		list.add_item(ch)
	list.select(0)
	split.add_child(list)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	var msgs := VBoxContainer.new()
	msgs.add_theme_constant_override("separation", 14)
	pad.add_child(msgs)
	scroll.add_child(pad)
	split.add_child(scroll)

	var history := [
		["Alex Kim", "PM · 09:01", "오늘부터 함께할 신입 개발자분이 오셨어요! 다들 환영해 주세요."],
		["Sophie Lee", "Frontend · 09:02", "환영해요! 모르는 거 있으면 편하게 물어보세요 :)"],
		["Daniel Park", "Senior · 09:04", "환영합니다. PR 올릴 때 테스트는 꼭 같이 부탁해요."],
		["Mina Choi", "QA · 09:12", "QA에서 버그 하나 올려뒀어요. 이슈 #001 확인 부탁드려요!"],
	]
	for m in history:
		msgs.add_child(_chat_message(m[0], m[1], m[2]))
	return split


static func _chat_message(who: String, meta: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var avatar := PanelContainer.new()
	var hue := float(absi(who.hash()) % 360) / 360.0
	avatar.add_theme_stylebox_override("panel", UITheme.box(Color.from_hsv(hue, 0.45, 0.7), 17))
	avatar.custom_minimum_size = Vector2(34, 34)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var initial := UITheme.label(who.left(1), 15, Color.WHITE)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	row.add_child(avatar)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	var name_label := UITheme.label(who, 14, Color("f0f2f5"))
	name_label.add_theme_font_override("font", UITheme.font(false, true))
	head.add_child(name_label)
	head.add_child(UITheme.label(meta, 12, Color("6b7385")))
	col.add_child(head)
	var body := UITheme.label(text, 14, Color("cfd5de"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	row.add_child(col)
	return row


# --- TaskBoard --------------------------------------------------------------

static func _tasks() -> Control:
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	pad.add_child(cols)
	var board := {
		"To Do": [["#001", "프로필 이름이 비어 있으면 'undefined' 표시", "bug", "나"],
				["#004", "결제 페이지 로딩 속도 개선", "feature", "미배정"]],
		"In Progress": [["#003", "주문 목록 페이지네이션", "feature", "Sophie"]],
		"Done": [["#002", "로그인 타임아웃 처리", "bug", "Daniel"]],
	}
	for column in board:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UITheme.box(Color("161a21"), 8, Color(0, 0, 0, 0), 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.add_child(UITheme.label("%s  (%d)" % [column, board[column].size()], 13, Color("8a93a5")))
		for card in board[column]:
			v.add_child(_task_card(card[0], card[1], card[2], card[3]))
			if card[0] == "#001":
				v.add_child(_checklist())
		panel.add_child(v)
		cols.add_child(panel)
	return pad


static func _task_card(id: String, title: String, kind: String, owner: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color("232834"), 8, Color("2f3542"), 10))
	var v := VBoxContainer.new()
	var t := UITheme.label("%s  %s" % [id, title], 13, Color("e6e8eb"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var tag_color := Color("e06c75") if kind == "bug" else Color("61afef")
	v.add_child(UITheme.label("%s · 담당: %s" % [kind, owner], 11, tag_color))
	card.add_child(v)
	return card


static func _checklist() -> Control:
	var box := VBoxContainer.new()
	for o in Game.objectives:
		var done: bool = o["done"]
		var l := UITheme.label(("  ✓ " if done else "  ○ ") + String(o["text"]), 12,
				Color("3ddc84") if done else Color("9aa4b5"))
		box.add_child(l)
	return box


# --- Wiki -------------------------------------------------------------------

static func _wiki() -> Control:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.selection_enabled = true
	r.add_theme_stylebox_override("normal", UITheme.box(Color("161a21"), 0, Color(0, 0, 0, 0), 18))
	r.add_theme_font_override("bold_font", UITheme.font(false, true))
	r.add_theme_font_override("mono_font", UITheme.font(true))
	r.text = """[font_size=22][b]Commerce Cloud[/b][/font_size]
[color=#8a93a5]NEXORA의 B2B 커머스 SaaS 백엔드 (commerce-api)[/color]

[b][color=#22c3c3]구조[/color][/b]
  • [code]src/auth[/code] — 로그인, 토큰
  • [code]src/orders[/code] — 주문
  • [code]src/payments[/code] — 결제
  • [code]src/users[/code] — 사용자 프로필

[b][color=#22c3c3]사용자 이름 표시 규칙[/color][/b]
  1. firstName과 lastName을 공백 하나로 연결한다.
  2. 각 값의 앞뒤 공백은 제거한다.
  3. 한쪽만 있으면 있는 쪽만 표시한다.
  4. 둘 다 비어 있으면 "Unknown User"를 표시한다.

[b][color=#22c3c3]협업 규칙[/color][/b]
  • main에 직접 push 금지. 브랜치 → PR → 리뷰 승인 후 병합.
  • 버그 수정 PR에는 회귀 테스트를 포함한다.

[b][color=#22c3c3]신입 온보딩: 작업 흐름[/color][/b]
  1. 테스트로 문제 확인: [code]npm test[/code]
  2. 작업 브랜치 만들기: [code]git switch -c fix/display-name[/code]
  3. DevIDE에서 코드 수정 후 [code]Ctrl+S[/code]
  4. 다시 [code]npm test[/code]
  5. 커밋: [code]git add .[/code] → [code]git commit -m "fix: ..."[/code]
  6. 올리기: [code]git push -u origin fix/display-name[/code]
"""
	return r


static func _placeholder(text: String) -> Control:
	var l := UITheme.label(text, 15, Color("9aa4b5"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
