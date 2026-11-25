extends VBoxContainer
## atlas.nexora.test — runs the repository's own src/atlas/dual_write.ts against this week's refund
## records (with the real outages) and shows what was saved, queued for retry, or silently lost.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SOURCE := "src/atlas/dual_write.ts"
const SKY := Color("7dd3fc")

var result := {}
var error := ""
var busy := false
var _body: VBoxContainer
var _run: Button


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var head := UITheme.hbox(10)
	var titles := UITheme.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UITheme.bold("ATLAS", 24, SKY))
	titles.add_child(UITheme.wrap(Game.L("이번 주 환불 기록 대조 · 저장소의 이중 기록 코드를 실제로 실행한 결과", "This week's refund reconciliation · the result of actually running the repository's dual-write code"), 13, UITheme.TEXT2))
	head.add_child(titles)
	_run = UITheme.button(Game.L("현재 코드로 다시 돌리기", "Re-run with current code"), "primary")
	_run.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_run.pressed.connect(func() -> void: await run())
	head.add_child(_run)
	add_child(head)
	_body = UITheme.vbox(12)
	add_child(_body)
	_render()
	if available():
		run.call_deferred()


func available() -> bool:
	return Workspace.is_ready and Workspace.exists() and FileAccess.file_exists(Workspace.resolve(SOURCE))


## Run this week's records through the working copy's writeBoth().
func run() -> Dictionary:
	if busy or not available():
		_render()
		return {}
	busy = true
	error = ""
	_render()
	var dir := ProjectSettings.globalize_path("user://sandbox/atlas_week")
	DirAccess.make_dir_recursive_absolute(dir)
	var ok := _write(dir.path_join("dual_write.ts"), Workspace.read_file(SOURCE)) \
		and _write(dir.path_join("atlas_week.mjs"), FileAccess.get_file_as_string("res://content/web/atlas/atlas_week.mjs"))
	var r: Dictionary = {}
	if ok:
		r = await Workspace.run("node", ["--experimental-permission", "--allow-fs-read=" + dir, "--experimental-strip-types", "--no-warnings", dir.path_join("atlas_week.mjs")], 8.0)
	busy = false
	result = {}
	if not ok or r.is_empty():
		error = Game.L("실행 파일을 준비하지 못했습니다.", "Could not prepare the run.")
	elif r["timed_out"]:
		error = Game.L("코드가 끝나지 않았어요. 무한 대기를 확인하세요.", "The code didn't finish. Check for an endless wait.")
	else:
		for line in String(r["out"]).split("\n"):
			if line.begins_with("CODIEN_ATLAS="):
				var parsed = JSON.parse_string(line.trim_prefix("CODIEN_ATLAS="))
				if parsed is Dictionary:
					result = parsed
		if result.is_empty():
			error = Game.L("코드를 실행하지 못했습니다.", "The code could not run.") + "\n" + Workspace.virtualize(String(r["err"])).left(300)
	if not result.is_empty():
		Game.emit_event("atlas_week", {"missing": (result["missing"] as Array).size(), "retry": (result["retry"] as Array).size()})
	_render()
	return result


func _write(path: String, body: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(body)
	f.close()
	return true


func _stat(title: String, value: String, color: Color, note := "") -> Control:
	var card := UITheme.panel(UITheme.BG2, 10, 12, color.darkened(0.6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UITheme.vbox(2)
	card.add_child(v)
	v.add_child(UITheme.label(title, 11, UITheme.MUTED))
	v.add_child(UITheme.bold(value, 24, color))
	if note != "":
		v.add_child(UITheme.wrap(note, 11, UITheme.TEXT2))
	return card


func _render() -> void:
	if _body == null:
		return
	UITheme.clear(_body)
	_run.disabled = busy or not available()
	if not available():
		_body.add_child(UITheme.wrap(Game.L("아직 저장소에 ATLAS 코드가 없습니다. Daniel이 이중 기록 초안을 올리면 여기서 이번 주 기록을 대조할 수 있어요.",
			"There's no ATLAS code in the repository yet. Once Daniel pushes the dual-write draft, this week's records can be reconciled here."), 13, UITheme.MUTED))
		return
	_body.add_child(UITheme.label(Game.L("실행한 코드: %s · 체크아웃 %s", "Code run: %s · checkout %s") % [SOURCE, Workspace.branch], 11, UITheme.MUTED))
	if busy:
		_body.add_child(UITheme.label(Game.L("이번 주 환불 40건을 다시 기록하는 중…", "Replaying this week's 40 refunds…"), 13, SKY))
		return
	if error != "":
		_body.add_child(UITheme.wrap(error, 12, UITheme.ERR))
		return
	if result.is_empty():
		return
	var res: Dictionary = result["results"]
	var missing: Array = result["missing"]
	var retry: Array = result["retry"]
	var crashed: Array = result["crashed"]
	var row := UITheme.hbox(10)
	row.add_child(_stat(Game.L("양쪽 저장", "Saved in both"), str(int(res.get("ok", 0))), UITheme.OK))
	row.add_child(_stat(Game.L("재처리 대기", "Queued for retry"), str(retry.size()), SKY, ", ".join(retry)))
	row.add_child(_stat(Game.L("조용히 사라짐", "Silently lost"), str(missing.size()), UITheme.ERR if not missing.is_empty() else UITheme.OK, ", ".join(missing)))
	row.add_child(_stat(Game.L("처리 중 오류", "Crashed"), str(crashed.size()), UITheme.WARN if not crashed.is_empty() else UITheme.OK, ", ".join(crashed)))
	_body.add_child(row)
	var verdict: String
	if not missing.is_empty():
		verdict = Game.L("원장이 꺼졌던 동안의 환불 %d건이 비교 기록에서 빠졌어요. 아무도 모르는 채로요." % missing.size(),
			"%d refunds from the ledger outage are missing from the comparison records, and nobody knows." % missing.size())
	elif result.get("duplicateRetry", false):
		verdict = Game.L("누락은 없지만 같은 기록이 재처리 목록에 두 번 들어갔어요. 재처리하면 두 번 기록돼요.", "Nothing is lost, but one record is queued twice. Reprocessing would write it twice.")
	elif not crashed.is_empty():
		verdict = Game.L("기존 저장소가 꺼진 순간 처리 자체가 멈췄어요. 실패를 결과로 돌려줘야 배치가 계속돼요.", "Processing stopped when the old store went down. Return the failure as a result so the batch keeps going.")
	else:
		verdict = Game.L("원장이 꺼졌던 동안의 환불 %d건이 모두 재처리 목록에 있어요. 잃어버린 기록 0건." % retry.size(),
			"All %d refunds from the ledger outage are in the retry list. Zero records lost." % retry.size())
	var good: bool = missing.is_empty() and crashed.is_empty() and not result.get("duplicateRetry", false)
	_body.add_child(UITheme.wrap(verdict, 14, UITheme.OK if good else UITheme.WARN))
	# What else this week's decisions produced.
	var flags: Dictionary = Game.state["flags"]
	var notes: Array = []
	if flags.get("c04_recon", false):
		notes.append(Game.L("대조 보고서: 실제 누락 1건 (ORD-3115, 이중 기록 이전)", "Reconciliation: 1 real omission (ORD-3115, before dual write)"))
	if int(flags.get("c04_pilot_findings", 0)) > 0:
		notes.append(Game.L("시범: 재결제 주문 차이 3건 — LEGACY-17 패턴", "Pilot: 3 re-payment differences — the LEGACY-17 pattern"))
	if flags.has("c04_manual_hours"):
		notes.append(Game.L("수동 대조: 주당 %d시간", "Manual reconciliation: %d hours a week") % int(flags["c04_manual_hours"]))
	for n in notes:
		_body.add_child(UITheme.label("· " + n, 12, UITheme.TEXT2))
