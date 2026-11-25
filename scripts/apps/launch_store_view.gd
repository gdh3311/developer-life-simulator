extends VBoxContainer
## moonlight.shop after the Chapter 3 launch: the customer's side of the pre-order feature.
## Everything here runs the repository's own src/preorder/*.ts: the deadline, the ship-by wording
## and what a cancel request does to each of the customer's orders.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const NIGHT := Color("141a33")
const CARD := Color("1c2344")
const MOON := Color("f4c95d")
const TEXT := Color("f2f0ff")
const MUTED := Color("b8b5d6")

var data := {}
var busy := false
var moment := "before"          # before | at | after the deadline minute
var reserved := 0
var cancelled := {}             # order id → result shown to the customer
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UITheme.box(NIGHT, 0, Color(0, 0, 0, 0), 0))
	add_child(bg)
	_body = UITheme.vbox(12)
	bg.add_child(UITheme.margin(_body, 18))
	_render()
	load_store.call_deferred()


static func launched() -> bool:
	return Game.state["flags"].get("c03_released", false)


func load_store() -> Dictionary:
	if busy or not (Workspace.is_ready and Workspace.exists()):
		return data
	busy = true
	_render()
	var dir := ProjectSettings.globalize_path("user://sandbox/preorder_store")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for name in ["deadline", "cancel", "labels"]:
		var rel := "src/preorder/%s.ts" % name
		if FileAccess.file_exists(Workspace.resolve(rel)):
			_write(dir.path_join(name + ".ts"), Workspace.read_file(rel))
	_write(dir.path_join("preorder_store.mjs"), FileAccess.get_file_as_string("res://content/web/store/preorder_store.mjs"))
	var lang := String(Game.state.get("repo_lang", Game.lang))
	var r: Dictionary = await Workspace.run("node", ["--experimental-permission", "--allow-fs-read=" + dir, "--experimental-strip-types", "--no-warnings", dir.path_join("preorder_store.mjs"), lang], 8.0)
	busy = false
	data = {}
	for line in String(r.get("out", "")).split("\n"):
		if line.begins_with("CODIEN_STORE="):
			var parsed = JSON.parse_string(line.trim_prefix("CODIEN_STORE="))
			if parsed is Dictionary:
				data = parsed
	_render()
	return data


func _write(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(body)
		f.close()


## Is the pre-order button live at the chosen moment? (from deadline.ts)
func open_now() -> bool:
	var d = data.get("deadline")
	return d is Dictionary and bool(d.get(moment, false))


func set_moment(m: String) -> void:
	moment = m
	_render()


func reserve() -> bool:
	if not open_now():
		return false
	reserved += 1
	Sfx.play("purchase", 1.1, -8.0)
	_render()
	return true


## The customer asks to cancel one of their orders (result comes from cancel.ts).
func cancel(order_id: String) -> Dictionary:
	for o in data.get("cancel", []):
		if o["id"] == order_id:
			cancelled[order_id] = o["result"]
			_render()
			return o["result"]
	return {}


func _render() -> void:
	if _body == null:
		return
	UITheme.clear(_body)
	_body.add_child(UITheme.bold(Game.L("☾ 달빛상점 · 봄 예약 판매", "☾ Moonlight · Spring pre-orders"), 20, TEXT))
	_body.add_child(UITheme.label(Game.L("손님 화면 · 저장소의 src/preorder 코드를 그대로 실행합니다", "Customer view · runs the repository's src/preorder code as is"), 11, MUTED))
	if busy and data.is_empty():
		_body.add_child(UITheme.label(Game.L("상점을 여는 중…", "Opening the store…"), 13, MOON))
		return
	if data.is_empty():
		_body.add_child(UITheme.label(Game.L("상점 코드를 실행하지 못했습니다.", "Could not run the store code."), 13, UITheme.ERR))
		return
	# Product with the ship-by line from labels.ts and the deadline from deadline.ts.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(CARD, 12, Color(0, 0, 0, 0), 14))
	var row := UITheme.hbox(14)
	card.add_child(row)
	var art := TextureRect.new()
	art.texture = load("res://content/web/studio/art/tea.svg") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(150, 110)
	row.add_child(art)
	var info := UITheme.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UITheme.bold(Game.L("벚꽃 녹차 (예약)", "Cherry blossom tea (pre-order)"), 16, TEXT))
	info.add_child(UITheme.label(Game.L("마감 3월 10일 23:00 (판매자 시간)", "Closes Mar 10, 23:00 (seller time)"), 12, MUTED))
	var label = data.get("labels")
	info.add_child(UITheme.wrap(String(label) if label is String else Game.L("(배송 문구 미출시)", "(ship-by wording not shipped)"), 13, MOON))
	var moments := UITheme.hbox(6)
	for m in [["before", Game.L("마감 1분 전", "1 min before")], ["at", Game.L("마감 정각", "Deadline minute")], ["after", Game.L("마감 30분 후", "30 min after")]]:
		var b := UITheme.button(m[1], "primary" if moment == m[0] else "default")
		var id: String = m[0]
		b.pressed.connect(func() -> void: set_moment(id))
		moments.add_child(b)
	info.add_child(moments)
	var reserve_btn := UITheme.button(Game.L("예약하기", "Pre-order") if open_now() else Game.L("마감됨", "Closed"), "ok" if open_now() else "default")
	reserve_btn.disabled = not open_now()
	reserve_btn.pressed.connect(func() -> void: reserve())
	info.add_child(reserve_btn)
	if reserved > 0:
		info.add_child(UITheme.label(Game.L("예약 %d건 완료", "%d pre-orders placed") % reserved, 12, UITheme.OK))
	row.add_child(info)
	_body.add_child(card)
	# My orders with cancel requests (cancel.ts).
	_body.add_child(UITheme.bold(Game.L("내 주문", "My orders"), 15, TEXT))
	var stage_names := {"placed": Game.L("접수", "Placed"), "preparing": Game.L("배송 준비", "Preparing"), "shipped": Game.L("발송됨", "Shipped")}
	for o in data.get("cancel", []) if data.get("cancel") is Array else []:
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", UITheme.box(CARD, 10, Color(0, 0, 0, 0), 10))
		var h := UITheme.hbox(10)
		line.add_child(h)
		var what := UITheme.label("%s  ·  %s  ·  %s" % [o["id"], Game.L("결제 완료", "Paid") if o["paid"] else Game.L("결제 전", "Unpaid"), stage_names.get(o["stage"], o["stage"])], 13, TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(what)
		if cancelled.has(o["id"]):
			var res: Dictionary = cancelled[o["id"]]
			var text := {"cancelled": Game.L("취소됐어요", "Cancelled"), "refund_requested": Game.L("환불 요청 접수", "Refund requested"),
				"needs_review": Game.L("판매자 확인 중", "Seller reviewing"), "rejected": Game.L("이미 발송돼 취소 불가", "Already shipped")}.get(String(res.get("state", "")), String(res.get("state", ""))) as String
			if bool(res.get("refund", false)):
				text += Game.L(" · 환불 진행", " · refund on the way")
			h.add_child(UITheme.label(text, 12, MOON))
		else:
			var b := UITheme.button(Game.L("취소 요청", "Request cancel"))
			var oid: String = o["id"]
			b.pressed.connect(func() -> void: cancel(oid))
			h.add_child(b)
		_body.add_child(line)
	for e in data.get("errors", []):
		_body.add_child(UITheme.label("· " + String(e), 10, MUTED))
