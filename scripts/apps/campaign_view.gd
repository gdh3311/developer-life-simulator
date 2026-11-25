extends VBoxContainer
## campaign.nexora.test — the spring campaign console. Before launch it shows last year's traffic
## per minute (the real shape behind "three times") and can rehearse the 20:00 rush; after launch it
## shows what actually happened. Every rush runs the repository's own reserve.ts, price_cache.ts and
## webhook.ts against the same buyers.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const ROSE := Color("fb7185")
const SOURCES := {"reserve.ts": "src/inventory/reserve.ts", "price_cache.ts": "src/pricing/price_cache.ts", "webhook.ts": "src/payments/webhook.ts"}
## Last year's campaign, requests per minute from 19:50 to 20:29.
const LAST_YEAR := [4, 4, 5, 5, 5, 6, 6, 7, 9, 14, 100, 47, 31, 24, 20, 17, 15, 13, 12, 11, 10, 9, 9, 8, 8, 7, 7, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4]

var result := {}
var busy := false
var error := ""
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var titles := UITheme.vbox(2)
	titles.add_child(UITheme.bold(Game.L("봄 한정 20시 오픈 · 캠페인 콘솔", "Spring limited, 20:00 · Campaign console"), 22, ROSE))
	titles.add_child(UITheme.wrap(Game.L("모든 결과는 저장소의 재고 예약·가격 캐시·결제 웹훅 코드를 실제로 실행해 계산합니다.",
		"Every result comes from actually running the repository's inventory, price cache and webhook code."), 12, UITheme.TEXT2))
	add_child(titles)
	_body = UITheme.vbox(12)
	add_child(_body)
	var saved = Game.state["flags"].get("c05_rush")
	if saved is Dictionary:
		result = saved
	_render()


static func launched() -> bool:
	return Game.state["flags"].get("c05_rush") is Dictionary


static func available() -> bool:
	if not (Workspace.is_ready and Workspace.exists()):
		return false
	for rel in SOURCES.values():
		if not FileAccess.file_exists(Workspace.resolve(rel)):
			return false
	return true


## Runs the 20:00 rush with a launch plan { stage, limit, extend } through the working copy's code.
## The plan goes over as three plain words (JSON quotes get mangled in Windows argv).
static func simulate(plan: Dictionary) -> Dictionary:
	if not available():
		return {"errors": ["missing code"]}
	var dir := ProjectSettings.globalize_path("user://sandbox/campaign_rush")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for name in SOURCES:
		_write(dir.path_join(name), Workspace.read_file(SOURCES[name]))
	_write(dir.path_join("campaign_rush.mjs"), FileAccess.get_file_as_string("res://content/web/campaign/campaign_rush.mjs"))
	var r: Dictionary = await Workspace.run("node", ["--experimental-permission", "--allow-fs-read=" + dir, "--experimental-strip-types", "--no-warnings",
		dir.path_join("campaign_rush.mjs"), String(plan.get("stage", "ten")), String(plan.get("limit", "keep")), String(plan.get("extend", "decline"))], 12.0)
	if r.is_empty() or r.get("timed_out", false):
		return {"errors": ["timeout"]}
	for line in String(r.get("out", "")).split("\n"):
		if line.begins_with("CODIEN_CAMPAIGN="):
			var parsed = JSON.parse_string(line.trim_prefix("CODIEN_CAMPAIGN="))
			if parsed is Dictionary:
				return parsed
	return {"errors": [Workspace.virtualize(String(r.get("err", ""))).left(200)]}


static func _write(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(body)
		f.close()


## A rehearsal with the plan chosen so far (or a cautious default) — nothing is saved.
func rehearse() -> Dictionary:
	if busy:
		return {}
	busy = true
	error = ""
	_render()
	var plan: Dictionary = Game.state["flags"].get("c05_launch", {"stage": "ten", "limit": "keep"}).duplicate()
	plan["extend"] = "decline"
	var r := await simulate(plan)
	busy = false
	if not r.has("minutes"):
		error = Game.L("리허설을 실행하지 못했어요: ", "Could not run the rehearsal: ") + ", ".join(r.get("errors", []))
	else:
		result = r
		result["rehearsal"] = true
	Game.emit_event("campaign_rehearsal", {"oversold": int(r.get("oversold", 0))})
	_render()
	return r


func _stat(title: String, value: String, color: Color, note := "") -> Control:
	var card := UITheme.panel(UITheme.BG2, 10, 12, color.darkened(0.6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UITheme.vbox(2)
	card.add_child(v)
	v.add_child(UITheme.label(title, 11, UITheme.MUTED))
	v.add_child(UITheme.bold(value, 22, color))
	if note != "":
		v.add_child(UITheme.wrap(note, 11, UITheme.TEXT2))
	return card


func _render() -> void:
	if _body == null:
		return
	UITheme.clear(_body)
	# Last year's shape: the reason "three times" is not a scenario.
	_body.add_child(UITheme.bold(Game.L("작년 행사 분당 요청 (19:50–20:29)", "Last year's campaign, requests per minute (19:50–20:29)"), 14, UITheme.TEXT))
	var bars: Array = []
	for i in LAST_YEAR.size():
		bars.append({"label": "20:%02d" % (i - 10) if i >= 10 else "19:%02d" % (50 + i), "value": LAST_YEAR[i], "hot": i == 10})
	_body.add_child(_chart(bars, 90))
	var avg := 0.0
	for v in LAST_YEAR:
		avg += v
	avg /= LAST_YEAR.size()
	_body.add_child(UITheme.wrap(Game.L("평균 %.1f건/분 · 20:00 첫 1분 100건 (평균의 %d배) · 10분 뒤엔 평균 근처", "Average %.1f/min · first minute at 20:00: 100 (%dx the average) · back near average ten minutes later")
		% [avg, roundi(100.0 / avg)], 12, UITheme.TEXT2))
	if not available():
		_body.add_child(UITheme.wrap(Game.L("재고 예약·가격 캐시·결제 웹훅 코드가 모두 저장소에 들어오면 20시 러시를 리허설할 수 있어요.",
			"Once the inventory, price cache and webhook code are all in the repository, you can rehearse the 20:00 rush."), 12, UITheme.MUTED))
		return
	var actions := UITheme.hbox(8)
	var rerun := UITheme.button(Game.L("현재 코드로 20시 리허설", "Rehearse 20:00 with current code"), "primary")
	rerun.disabled = busy
	rerun.pressed.connect(func() -> void: await rehearse())
	actions.add_child(rerun)
	_body.add_child(actions)
	if busy:
		_body.add_child(UITheme.label(Game.L("구매자 1,300명이 20:00에 버튼을 누르는 중…", "1,300 buyers pressing the button at 20:00…"), 13, ROSE))
		return
	if error != "":
		_body.add_child(UITheme.wrap(error, 12, UITheme.ERR))
	if result.is_empty() or not result.has("minutes"):
		return
	_body.add_child(UITheme.bold(Game.L("리허설 결과 (저장 안 됨)", "Rehearsal (not saved)") if result.get("rehearsal", false) else Game.L("행사 결과 · 실제 20:00", "Campaign result · the real 20:00"), 15, UITheme.TEXT))
	var row := UITheme.hbox(10)
	row.add_child(_stat(Game.L("판매", "Sold"), "%d / %d" % [int(result["sold"]), int(result["stock"]) + int((result.get("extra") if result.get("extra") is Dictionary else {}).get("stock", 0))], UITheme.OK, Game.L("품절 %s", "sold out %s") % String(result.get("soldOutAt", "-")) if result.get("soldOutAt") != null else ""))
	row.add_child(_stat(Game.L("초과 판매", "Oversold"), str(int(result["oversold"])), UITheme.ERR if int(result["oversold"]) > 0 else UITheme.OK))
	row.add_child(_stat(Game.L("중복 청구", "Double charges"), str(int(result["duplicateCharges"])), UITheme.ERR if int(result["duplicateCharges"]) > 0 else UITheme.OK))
	row.add_child(_stat(Game.L("틀린 가격 결제", "Wrong-price charges"), str(int(result["wrongPrice"])), UITheme.ERR if int(result["wrongPrice"]) > 0 else UITheme.OK))
	_body.add_child(row)
	var row2 := UITheme.hbox(10)
	var recon: Array = result.get("reconcile", [])
	row2.add_child(_stat(Game.L("조정 목록 (사람 확인)", "Reconciliation (a person checks)"), str(recon.size()), UITheme.WARN if not recon.is_empty() else UITheme.OK,
		Game.L("취소 뒤 도착한 결제 성공", "payments that arrived after cancelling") if not recon.is_empty() else ""))
	row2.add_child(_stat(Game.L("만료 안 된 예약에 묶인 재고", "Stock stuck in holds"), str(int(result.get("stuck", 0))), UITheme.ERR if int(result.get("stuck", 0)) > 0 else UITheme.OK))
	row2.add_child(_stat(Game.L("결제사 오류 화면", "Gateway error pages"), str(int(result.get("gatewayErrors", 0))), UITheme.WARN if int(result.get("gatewayErrors", 0)) > 0 else UITheme.OK))
	row2.add_child(_stat(Game.L("대기열 최대", "Peak queue"), str(int(result.get("queuePeak", 0))), UITheme.TEXT2, Game.L("대기 안내 화면", "waiting-room notice")))
	_body.add_child(row2)
	# The big revenue graph: minute by minute.
	var revenue: Array = []
	var total := 0
	for m in result["minutes"]:
		if m["label"] != "main" or int(m["m"]) > 14:
			continue
		total += int(m["won"])
		revenue.append({"label": "20:%02d" % int(m["m"]), "value": total, "hot": false})
	_body.add_child(UITheme.bold(Game.L("누적 매출 %s", "Cumulative revenue %s") % Game.won(int(result.get("revenue", 0))), 14, UITheme.OK))
	_body.add_child(_chart(revenue, 80, UITheme.OK))
	if result.get("extra") is Dictionary:
		var ex: Dictionary = result["extra"]
		_body.add_child(UITheme.label(Game.L("달빛상점 연장 판매: %d분 · %d / %d개", "Moonlight extension: %d min · %d / %d items") % [int(ex["minutes"]), int(ex["sold"]), int(ex["stock"])], 12, UITheme.TEXT2))
	for e in result.get("errors", []):
		_body.add_child(UITheme.label("· " + String(e), 10, UITheme.MUTED))


func _chart(bars: Array, height: float, color := ROSE) -> Control:
	var chart := BarChart.new()
	chart.bars = bars
	chart.color = color
	chart.custom_minimum_size = Vector2(0, height)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return chart


class BarChart extends Control:
	var bars: Array = []
	var color := Color("fb7185")

	func _draw() -> void:
		if bars.is_empty():
			return
		var top := 1.0
		for b in bars:
			top = maxf(top, float(b["value"]))
		var w := size.x / bars.size()
		for i in bars.size():
			var h := (size.y - 14.0) * float(bars[i]["value"]) / top
			var c: Color = color if bars[i].get("hot", false) or color != Color("fb7185") else color.darkened(0.45)
			draw_rect(Rect2(i * w + 1.0, size.y - 14.0 - h, maxf(1.0, w - 2.0), h), c)
		var font := get_theme_default_font()
		for i in [0, bars.size() / 2, bars.size() - 1]:
			draw_string(font, Vector2(i * w, size.y - 2.0), String(bars[i]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8a93a6"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
