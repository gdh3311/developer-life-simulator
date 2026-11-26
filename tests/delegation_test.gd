extends Node
## Delegation (Story.delegation): the "who takes this check?" form and its reports.
##  - Warnings under each person match exactly what later happens (trust bar, Jiwoo's reach from
##    mentoring_evidence, a missing flag, load across the form, away).
##  - Reports arrive after game time, in due order; a stuck piece names why and reopens alone;
##    reassigning it finishes the request with delegation_done.
##  - Raising the evidence grade or setting the flag removes the warning.
##  - A request survives a save while reports are pending; the clock wiring delivers them.
##  - The Docs form shows the warnings and submits through the shared Docs path.

const DocsApp := preload("res://scripts/apps/docs_app.gd")
var _checks := 0
var _failures := 0
var _events: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("DL_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func _fresh() -> void:
	Game.reset_state()
	Game.lang = "ko"
	Game.state["day"] = 22
	Game.state["rel"]["jiwoo"] = {"tech": 50, "work": 30, "close": 20, "agree": 30}
	Game.state["rel"]["mina"]["tech"] = 50
	Game.state["rel"]["daniel"]["tech"] = 70
	Story.active = null
	Story.evidence = Story.Evidence.new()
	Story.delegation = Story.Delegation.new()
	_events.clear()


func _spec(id := "c07_check") -> Dictionary:
	return {
		"id": id, "mission": "test",
		"title": {"ko": "이 확인은 누가 할까요?", "en": "Who takes these checks?"},
		"intro": {"ko": "반나절 자리를 비우기 전에 확인 세 가지를 나눕니다.", "en": "Split three checks before half a day away."},
		"people": ["jiwoo", "mina", "daniel"],
		"pieces": [
			{"id": "smoke", "text": {"ko": "배송비 스모크 테스트", "en": "Shipping fee smoke test"}, "kind": "tech", "size": 1, "hours": 1, "minutes": 30},
			{"id": "boxes", "text": {"ko": "상자 수 경계값 확인", "en": "Box count edge cases"}, "kind": "tech", "size": 2, "hours": 2, "minutes": 60},
			{"id": "notes", "text": {"ko": "릴리스 노트 검토", "en": "Release note review"}, "kind": "work", "size": 1, "hours": 1, "minutes": 45},
		],
	}


func _warns(form: Dictionary, slot_id: String, who: String) -> Array:
	for slot in form["slots"]:
		if slot["id"] == slot_id:
			for o in slot["options"]:
				if o["id"] == who:
					return o.get("warn", [])
	return ["<missing option>"]


func _has_ok(form: Dictionary, slot_id: String, who: String) -> bool:
	for slot in form["slots"]:
		if slot["id"] == slot_id:
			for o in slot["options"]:
				if o["id"] == who:
					return o.has("ok")
	return false


func _said(who: String) -> Array:
	return (Game.state["chat"] as Array).filter(func(m: Dictionary) -> bool: return m["from"] == who).map(func(m: Dictionary) -> String: return Game.tx(m["text"]))


func _to(mins: int) -> void:
	Game.state["minutes"] = mins
	Story.delegation.check()


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.event.connect(func(kind: String, d: Dictionary) -> void:
		if kind.begins_with("delegation_"):
			_events.append([kind, d]))
	_warnings()
	_rounds()
	_unlocks()
	_load_and_away()
	await _round_trip()
	await _docs()
	finish()


func _warnings() -> void:
	_fresh()
	var dl = Story.delegation
	dl.open(_spec())
	dl.open(_spec())
	check((Game.state["delegation"]["requests"] as Dictionary).size() == 1 and _events.size() == 1, "opening twice keeps one request")
	var form: Dictionary = dl.open_forms()[0]
	check(form["slots"].size() == 3 and form["owner"] == "delegation" and not form["done"], "one slot per piece")
	check(form["slots"][0]["options"].size() == 4 and form["slots"][0]["options"][3]["id"] == "me", "three teammates plus 'I'll do it'")
	check(_warns(form, "smoke", "jiwoo").is_empty() and _has_ok(form, "smoke", "jiwoo"), "Jiwoo can take a small tech piece")
	var reach: Array = _warns(form, "boxes", "jiwoo")
	check(reach.size() == 1 and Game.tx(reach[0]).contains("멘토링") and Game.tx(reach[0]).contains("작은 일"), "no mentoring record limits Jiwoo to small pieces")
	check(_warns(form, "boxes", "mina").is_empty(), "Mina's tech 50 clears the medium bar (45)")
	var low: Array = _warns(form, "notes", "daniel")
	check(low.size() == 1 and Game.tx(low[0]).contains("업무 신뢰") and Game.tx(low[0]).contains("15"), "Daniel's work trust 15 is below the small bar and the warning says so")
	check(_warns(form, "boxes", "me").is_empty() and not _has_ok(form, "boxes", "me"), "doing it yourself has no warning and no badge")


func _rounds() -> void:
	_fresh()
	var dl = Story.delegation
	dl.open(_spec())
	var form: Dictionary = dl.open_forms()[0]
	check(not DocsApp.submit(form, {"smoke": "jiwoo"}).is_empty(), "every piece needs an owner")
	var start := Game.minutes()
	check(DocsApp.submit(form, {"smoke": "jiwoo", "boxes": "jiwoo", "notes": "me"}).is_empty(), "warnings do not block handing off")
	check(dl.status("c07_check") == "waiting", "request waits for reports")
	check(dl.open_forms()[0]["done"] and dl.open_forms()[0]["status_lines"].size() == 3, "the form shows each piece's status while waiting")
	check(dl.job("c07_check", "notes")["status"] == "self", "my own piece is mine right away")
	check(dl.load_of("jiwoo") == 3, "Jiwoo holds three hours")
	_to(start + 29)
	check(_said("jiwoo").is_empty(), "no report before it is due")
	_to(start + 90)
	var said := _said("jiwoo")
	check(said.size() == 2, "both reports arrive once due (%d)" % said.size())
	check(said[0].contains("배송비 스모크 테스트") and said[0].contains("문제없습니다"), "the small piece reports success first")
	check(said[1].contains("상자 수 경계값 확인") and said[1].contains("멈춘 이유") and said[1].contains("멘토링"), "the stuck report names the same reason the warning showed")
	var reported := _events.filter(func(e: Array) -> bool: return e[0] == "delegation_reported")
	check(reported.size() == 2 and reported[0][1]["ok"] and not reported[1][1]["ok"] and reported[1][1]["reason"] == "reach", "report events carry ok and reason")
	check(dl.status("c07_check") == "open" and dl.open_pieces("c07_check").size() == 1, "only the stuck piece reopens")
	var again: Dictionary = dl.open_forms()[0]
	check(again["slots"].size() == 1 and Game.tx(_warns(again, "boxes", "jiwoo")[0]).contains("지난번"), "the reopened form remembers who got stuck")
	check(DocsApp.submit(again, {"boxes": "mina"}).is_empty(), "reassign to Mina")
	_to(start + 200)
	var done := _events.filter(func(e: Array) -> bool: return e[0] == "delegation_done")
	check(done.size() == 1 and done[0][1]["results"] == {"smoke": "jiwoo", "boxes": "mina", "notes": "me"}, "delegation_done lists who finished each piece")
	check(dl.open_forms().is_empty() and dl.delegated_ok("c07_check").size() == 2, "a finished request leaves Docs")
	check(Game.rel("mina", "work") > 20, "a good report raises work trust")


func _unlocks() -> void:
	_fresh()
	var dl = Story.delegation
	var spec := _spec("c12_runbook")
	spec["pieces"] = [{"id": "run", "text": {"ko": "운영 문서대로 처리", "en": "Follow the runbook"}, "kind": "tech", "size": 2, "hours": 2, "minutes": 30,
		"needs": [{"flag": "runbook_restart_step", "text": {"ko": "운영 문서에 재시작 단계가 없어요.", "en": "The runbook has no restart step."}}],
		"report_fail": {"needs": {"ko": "문서 4단계에서 멈췄어요. 재시작 방법이 안 적혀 있어요.", "en": "Stopped at step 4. The restart isn't written down."}}}]
	dl.open(spec)
	var warns := _warns(dl.open_forms()[0], "run", "jiwoo")
	check(warns.size() == 2, "Jiwoo: reach and the missing runbook line (%d)" % warns.size())
	Story.evidence.raise("mentoring_evidence", "explained", "jw_shipping")
	warns = _warns(dl.open_forms()[0], "run", "jiwoo")
	check(warns.size() == 1 and Game.tx(warns[0]).contains("재시작"), "explained mentoring lifts Jiwoo's reach to medium")
	var start := Game.minutes()
	DocsApp.submit(dl.open_forms()[0], {"run": "jiwoo"})
	_to(start + 30)
	check(_said("jiwoo")[-1].contains("4단계"), "a piece's own failure text is used")
	Game.state["flags"]["runbook_restart_step"] = true
	check(_warns(dl.open_forms()[0], "run", "jiwoo").size() == 1, "after fixing the doc only the 'stopped here last time' note remains")
	DocsApp.submit(dl.open_forms()[0], {"run": "jiwoo"})
	_to(start + 60)
	check(dl.status("c12_runbook") == "done" and dl.job("c12_runbook", "run")["status"] == "ok", "the same person succeeds once the line exists")


func _load_and_away() -> void:
	_fresh()
	var dl = Story.delegation
	var spec := _spec("c11_split")
	spec["away"] = ["daniel"]
	spec["pieces"] = [
		{"id": "a", "text": {"ko": "지원 창 확인", "en": "Support view"}, "kind": "tech", "size": 1, "hours": 3},
		{"id": "b", "text": {"ko": "운영 창 확인", "en": "Ops view"}, "kind": "tech", "size": 1, "hours": 2},
	]
	dl.open(spec)
	var form: Dictionary = dl.form_spec("c11_split", {"a": "mina"})
	check(Game.tx(_warns(form, "b", "mina")[0]).contains("3시간"), "picking Mina for 3 h warns on her next 2 h piece (cap 4)")
	check(_warns(form, "b", "jiwoo").is_empty(), "others are unaffected")
	check(Game.tx(_warns(form, "a", "daniel")[0]).contains("자리에 없어요"), "away people are warned")
	var start := Game.minutes()
	DocsApp.submit(dl.open_forms()[0], {"a": "mina", "b": "mina"})
	_to(start + 60)
	check(dl.job("c11_split", "a")["status"] == "ok" and dl.job("c11_split", "b")["status"] == "failed", "the overloaded piece fails, the first succeeds")
	check(_said("mina")[-1].contains("맡은 일이 너무"), "the load failure says so")


func _round_trip() -> void:
	_fresh()
	Story.delegation.open(_spec())
	DocsApp.submit(Story.delegation.open_forms()[0], {"smoke": "mina", "boxes": "mina", "notes": "me"})
	var saved := JSON.stringify(Game.state)
	_fresh()
	Game.state = JSON.parse_string(saved)
	Story.delegation = Story.Delegation.new()
	check(Story.delegation.status("c07_check") == "waiting", "a pending request survives a save")
	Game.advance(120)   # the clock wiring in Story delivers due reports
	await get_tree().process_frame
	check(Story.delegation.status("c07_check") == "done" and Story.delegation.delegated_ok("c07_check").size() == 2, "reports arrive after loading as time passes")


func _docs() -> void:
	_fresh()
	Story.delegation.open(_spec())
	var docs: Control = DocsApp.new()
	docs.size = Vector2(1000, 700)
	add_child(docs)
	await get_tree().process_frame
	var notes := docs.find_children("OptionNotes", "", true, false)
	check(notes.size() == 9, "every option except 'I'll do it' carries a note (%d)" % notes.size())
	var texts: Array = []
	for n in docs.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var joined := " | ".join(texts)
	check(joined.contains("이 확인은 누가 할까요?") and joined.contains("⚠") and joined.contains("✓ 맡길 수 있어요"), "Docs shows the form with warnings and badges")
	var box: CheckBox = null
	for b in docs.find_children("*", "CheckBox", true, false):
		if (b as CheckBox).text.begins_with("Mina"):
			box = b
			break
	box.button_pressed = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(docs._picks.get("delegation:c07_check", {}).get("smoke", "") == "mina", "picking in Docs records the choice and survives the live re-render")
	await capture("delegation_form")
	docs.queue_free()


func finish() -> void:
	print("DELEGATION_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	Sfx.stop_all()
	for player in Sfx._players + [Sfx._featured] + Sfx._score_players.values():
		player.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
