extends Node
## Evidence record: grades backfilled from finished chapters 1–6 without notices, rules used once,
## live updates on mission finish and form submit, raise/lower/history semantics, choice keys,
## the concentrated vs shared paths, save round-trip, and the Dashboard card.

const RecordPanel := preload("res://scripts/apps/evidence_panel.gd")
var _checks := 0
var _failures := 0
var _toasts: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("EV_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func _done(ids: Array) -> void:
	for id in ids:
		Game.state["story"][id] = {"status": "done", "obj": {}, "data": {}}


func _fresh() -> void:
	Game.reset_state()
	Game.lang = "ko"
	Story.evidence = Story.Evidence.new()
	_toasts.clear()


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.toast.connect(func(app: String, title: String, body: String) -> void:
		if app == "dashboard":
			_toasts.append(body))
	_empty()
	_backfill_shared()
	_backfill_concentrated()
	_semantics()
	await _live()
	_round_trip()
	await _panel()
	finish()


func _empty() -> void:
	_fresh()
	var ev = Story.evidence
	check(ev.refresh().is_empty(), "a new game has nothing to record")
	check(ev.grade("idempotency_evidence") == "" and ev.rank("idempotency_evidence") == -1, "unrecorded keys have no grade")
	check(not ev.at_least("handoff_quality", "personal"), "unrecorded is below every grade")
	check(Game.state["evidence"]["seeded"] == true, "first refresh marks the save as seeded")


## A finished chapter 6 save where the player split the work.
func _backfill_shared() -> void:
	_fresh()
	Game.state["day"] = 18
	_done(["c02_03", "c02_04", "c02_06", "c03_07", "c04_03", "c04_04", "c05_04", "c05_05", "c06_03", "c06_04", "c06_05", "c06_06"])
	Game.state["flags"]["c03_owner"] = "pair"
	Game.state["flags"]["c05_rota_self"] = 1
	var ev = Story.evidence
	var changed: Array = ev.refresh()
	check(changed.size() == 5, "backfill fills five keys from chapters 1–6 (%d)" % changed.size())
	check(_toasts.is_empty(), "backfill on an older save shows no notices")
	check(ev.grade("idempotency_evidence") == "concurrent", "concurrent duplicates from C02 M06")
	check(ev.source_text("idempotency_evidence") == "버튼 바깥의 중복", "the source names the mission")
	check(ev.first_grade("idempotency_evidence") == "sequential", "history keeps the first grade (sequential)")
	check(ev.grade("log_contract") == "minimal", "log contract minimal from C02 M04")
	check(ev.grade("ledger_evidence") == "reconciled", "ledger reconciled after C04 M04 and the C06 rehearsal")
	check(ev.grade("handoff_quality") == "documented", "handoffs documented")
	check(ev.grade("shared_ownership") == "verified", "split work then agreed with the other team is verified")
	check(ev.grade("mentoring_evidence") == "" and ev.grade("career_focus") == "", "chapter 7+ keys stay empty")
	check(ev.refresh().is_empty(), "rules are used once")
	check((Game.state["evidence"]["applied"] as Array).size() == 13, "thirteen rules applied (the take-every-shift rule did not)")


## Same save, but the player took every night shift and kept ownership alone.
func _backfill_concentrated() -> void:
	_fresh()
	Game.state["day"] = 18
	_done(["c03_07", "c05_05", "c06_04"])
	Game.state["flags"]["c03_owner"] = "me"
	Game.state["flags"]["c05_rota_self"] = 3
	var ev = Story.evidence
	ev.refresh()
	check(ev.grade("shared_ownership") == "assigned", "agreeing owners in C06 lifts concentrated to assigned, not verified")
	check(ev.first_grade("shared_ownership") == "concentrated", "the concentrated start stays in history")
	check(not ev.at_least("ledger_evidence", "untracked"), "no ledger work → no ledger grade")
	check(ev.next_text("ledger_evidence") != "", "an empty key still says how to start")


func _semantics() -> void:
	_fresh()
	var ev = Story.evidence
	ev.refresh()
	check(ev.raise("handoff_quality", "documented", "c03_07"), "raise records a first grade")
	check(not ev.raise("handoff_quality", "personal", "test"), "raise never lowers")
	check(ev.set_grade("handoff_quality", "personal", "test"), "set_grade can lower (a later chapter's consequence)")
	check(ev.grade("handoff_quality") == "personal" and ev.first_grade("handoff_quality") == "documented", "lowering keeps the history")
	check((ev.entry("handoff_quality")["history"] as Array).size() == 2, "two history entries")
	check(not ev.set_grade("handoff_quality", "personal", "test"), "setting the same grade is a no-op")
	check(not ev.set_grade("handoff_quality", "legendary", "test"), "unknown grades are refused")
	check(not ev.set_grade("nonsense", "x", "test"), "unknown keys are refused")
	check(ev.raise("career_focus", "lead", "c07_08"), "a choice key records the first decision")
	check(not ev.raise("career_focus", "technical", "test"), "raise does not overwrite a choice")
	check(ev.set_grade("career_focus", "technical", "c09_07"), "set_grade can change a choice")
	check(ev.next_text("career_focus") == "", "choices have no 'next step'")
	ev.set_grade("idempotency_evidence", "concurrent", "c02_06")
	check(ev.next_text("idempotency_evidence") == "", "top grade has no 'next step'")


func _live() -> void:
	_fresh()
	Game.state["day"] = 5
	var ev = Story.evidence
	ev.refresh()
	var m = Story.mission("c02_03")
	Game.state["story"]["c02_03"] = {"status": "active", "obj": {}, "data": {}}
	Story.active = null
	Story.finish_mission(m)
	check(ev.grade("idempotency_evidence") == "sequential", "finishing a mission updates the record right away")
	check(_toasts.size() == 1 and String(_toasts[0]).contains("순차 재전송"), "a live change shows one notice")
	# Form path: a done mission whose effect is a flag, recorded on the next form_submitted.
	_done(["c03_07"])
	Game.state["flags"]["c03_owner"] = "pair"
	Game.emit_event("form_submitted", {"form": "own"})
	check(ev.grade("handoff_quality") == "documented" and ev.grade("shared_ownership") == "assigned", "form_submitted refreshes the record")
	await get_tree().process_frame


func _round_trip() -> void:
	_fresh()
	Game.state["day"] = 18
	_done(["c02_03", "c02_06", "c06_06"])
	Story.evidence.refresh()
	var saved := JSON.stringify(Game.state["evidence"])
	_fresh()
	Game.state["evidence"] = JSON.parse_string(saved)
	var ev = Story.evidence
	check(ev.grade("idempotency_evidence") == "concurrent" and ev.first_grade("idempotency_evidence") == "sequential", "grades and history survive a save")
	check(ev.refresh().is_empty() and _toasts.is_empty(), "a loaded save does not reapply rules")


func _panel() -> void:
	_fresh()
	Game.state["day"] = 1
	check(RecordPanel.dashboard() == null, "no card in chapter 1")
	Game.state["day"] = 18
	_done(["c02_03", "c02_04", "c02_06", "c03_07", "c04_03", "c04_04", "c05_05", "c06_04", "c06_05", "c06_06"])
	Game.state["flags"]["c03_owner"] = "pair"
	Game.state["flags"]["c05_rota_self"] = 1
	Story.evidence.refresh()
	check(Story.evidence.visible_keys().size() == 5, "chapter 6 shows the five keys it can have")
	Story.evidence.raise("career_focus", "lead", "test")
	check(Story.evidence.visible_keys().size() == 6, "a later key appears early once it has a grade")
	Story.evidence.set_grade("career_focus", "undecided", "test")
	var dash: Control = preload("res://scripts/apps/dashboard_app.gd").new()
	dash.size = Vector2(1000, 700)
	add_child(dash)
	await get_tree().process_frame
	var card := dash.find_child("EvidencePanel", true, false)
	check(card != null, "Dashboard shows the My record card")
	var texts: Array = []
	for n in card.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var joined := " | ".join(texts)
	check(joined.contains("내 기록") and joined.contains("동시 요청까지 확인") and joined.contains("양쪽이 확인함"), "card shows names and grades")
	check(joined.contains("근거: 버튼 바깥의 중복") and joined.contains("처음엔 '순차 재전송 확인'"), "card shows the source and first grade")
	if dash is ScrollContainer:
		(dash as ScrollContainer).scroll_vertical = int((card as Control).global_position.y - dash.global_position.y) - 12
	await get_tree().process_frame
	await capture("evidence_dashboard")
	dash.queue_free()


func finish() -> void:
	print("EVIDENCE_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	# Notice sounds can still be playing; their playback would show up as a leak at exit.
	Sfx.stop_all()
	for player in Sfx._players + [Sfx._featured] + Sfx._score_players.values():
		player.stream = null
	# The audio thread drops stopped playbacks on its own schedule; give it real time.
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
