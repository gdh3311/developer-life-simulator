extends Node
## Targeted legacy-save boundary + real Git/Node/IDE/CI replay, across two processes.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Desktop := preload("res://scripts/desktop/desktop.gd")
const LabApp := preload("res://scripts/apps/request_lab_app.gd")
var _checks := 0
var _failures := 0
var _stage := "before"
var _profile := "prevent"
var _terminal: Control
var _ide: Control
var _desktop: Control
var _running := false


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C02_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func wait_until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok := bool(predicate.call())
	check(ok, label)
	return ok


func active(id: String) -> bool:
	return Story.active != null and Story.active.id == id and Story.status(id) == "active" and Story.active.data().get("_intro_complete", false)


func command(line: String) -> void:
	await _terminal._execute(_terminal.tokenize(line))


func edit(content: String, path := "src/orders/request.ts") -> void:
	_ide.open_file(path)
	_ide._code.text = content
	_ide.save()
	await get_tree().create_timer(0.1, true, false, true).timeout


func probe(network: String, retry := true, version := "current", keys := "same", timing := "sequential") -> Dictionary:
	var result := await RequestLab.run_probe({"network": network, "retry": retry, "keys": keys, "clicks": 1, "version": version, "timing": timing})
	if not result.get("ok", false):
		print("C02_PROBE_ERROR: ", result)
	check(result.get("ok", false), "actual-code experiment: " + network + "/" + str(retry) + "/" + version + "/" + keys)
	return result


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func lab_preview(name: String) -> void:
	var lab := LabApp.new()
	lab.theme = UITheme.build()
	lab.position = Vector2(40, 40)
	lab.size = Vector2(860, 560)
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	check(lab.get_combined_minimum_size().x <= 860, "Lab fits the application width")
	await capture(name)
	lab.queue_free()
	await get_tree().process_frame


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if "--stage" in args:
		_stage = args[args.find("--stage") + 1]
	if "--profile" in args:
		_profile = args[args.find("--profile") + 1]
	Game.lang = "en" if _profile == "recover" else "ko"
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.reset_state()
	if _stage in ["after", "finale"]:
		check(Game.load_game(), "loaded the previous process's checkpoint")
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	_running = true
	if _stage == "before":
		await before_restart()
	elif _stage == "finale":
		await finale()
	else:
		await after_restart()
	await finish()


func before_restart() -> void:
	# Seed only the old boundary: C1 itself is covered by chapter_test's full replay.
	Game.state["player_name"] = "Continuing Developer"
	Game.state["day"] = 4
	Game.state["day_done"] = true
	Game.state["rank"] = 1
	Game.state["money"] = 123456
	Game.state["flags"]["ending"] = "left" if _profile == "recover" else "stayed"
	Game.state["flags"]["kept_choice"] = "custom"
	Game.state["rel"]["daniel"]["tech"] = 63
	for mission in Story.chapter_missions(1):
		Game.state["story"][mission.id] = {"status": "done", "obj": {}, "data": {}}
	Game._save()
	# A pre-C2 version-one save has no Lab key; load must add it without losing values.
	var legacy: Dictionary = Game.state.duplicate(true)
	legacy.erase("request_lab")
	var file := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(Game.load_game() and Game.state.has("request_lab"), "legacy C1 save receives additive Lab defaults")
	check(Game.money() == 123456 and Game.rel("daniel", "tech") == 63, "legacy values survive migration")
	for invalid in [{"runs": "broken"}, {"plan": 3}, {"runs": [{"config": {}}]}, {"latest": []}]:
		var corrupt: Dictionary = Game.state.duplicate(true)
		corrupt["request_lab"].merge(invalid, true)
		var invalid_path := "user://sandbox/invalid-lab.json"
		var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
		invalid_file.store_string(JSON.stringify(corrupt))
		invalid_file.close()
		check(not Game.SaveStore._read_one(invalid_path, Game._default_state())["ok"], "malformed Lab save data is rejected before UI access")
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Story.can_continue_chapter(), "completed C1 restores a playable continuation")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter1_continue")
	var paid := Game.money()
	_desktop._continue_chapter()
	_desktop._continue_chapter()
	if not await wait_until(func() -> bool: return active("c02_01"), "entered C2 through the desktop continuation"):
		return
	check(Game.day() == 5 and Game.chapter() == 2 and Game.money() == paid, "double click advances once and pays once")
	check(Game.state["rank"] == 1 and Game.state["flags"]["kept_choice"] == "custom" and Game.rel("daniel", "tech") == 63, "career, choices and relationships are preserved")
	check(Game.state["flags"]["ending"] == ("left" if _profile == "recover" else "stayed"), "legacy career choice is preserved")
	check("MON" in Game.date_text() and not "FRI" in Game.date_text(), "chapter-two narrative date starts on Monday")
	check(Story.chapter_missions(1).size() == 10 and Story.chapter_missions(2).size() == 8, "chapter progress counts are separated")
	_desktop.queue_free()
	await get_tree().process_frame
	check(not RequestLab.save_plan(["payment"]), "a guess without records cannot finish customer investigation")
	await lab_preview("ticket_" + Game.lang)
	check(Story.active.is_done("ticket"), "reading the real Lab ticket completes the ticket objective")
	RequestLab.inspect_records()
	check(not RequestLab.save_plan(["request"]), "reproduction plan needs the resend comparison")
	check(RequestLab.save_plan(["request", "retries", "payment"]), "evidence-based reproduction plan is accepted")
	if not await wait_until(func() -> bool: return active("c02_02"), "customer investigation unlocks reproduction"):
		return
	check(Game.state["flags"].get("c02_ask", "") == ("direct" if _profile == "recover" else "narrow"), "Yuri's first question is answered")
	await wait_until(func() -> bool: return Game.state["chat"].any(func(m: Dictionary) -> bool: return "ORD-1044" in Game.tx(m["text"])), "asking the customer brings back the order number")
	await command('git config user.name "Continuing Developer"')
	await command("git config user.email continuing@example.invalid")
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync") and "createOrder" in Workspace.read_file("src/orders/request.ts"), "NPC's real module arrives via pull")
	check(not (await RequestLab.run_probe({"network": "invalid"})).get("ok", false), "invalid experiment options do not create observations")
	var fast := await probe("fast")
	check(int(fast.get("created", 0)) == 1, "normal response creates one order")
	var duplicate := await probe("slow")
	check(int(duplicate.get("attempts", 0)) == 2 and int(duplicate.get("created", 0)) == 2, "delayed retry reproduces two actual orders")
	check(Story.active.is_done("duplicate") and not Story.active.is_done("isolate"), "reproduction still requires a controlled comparison")
	await lab_preview("duplicate_" + Game.lang)
	Game._save()
	check(Game.state["request_lab"]["runs"].size() == 2, "checkpoint contains real experiment history")
	var saved := Game.SaveStore._read_one(Game.SAVE_PATH, Game._default_state())
	check(saved["ok"] and saved["data"]["request_lab"]["runs"].size() == 2, "serialized numeric conditions survive save validation")


func after_restart() -> void:
	check(Game.day() == 5 and Game.state["request_lab"]["runs"].size() == 2, "restart preserves chapter and observations")
	await Story.resume()
	if not await wait_until(func() -> bool: return active("c02_02"), "resumed the unfinished reproduction task"):
		return
	check(Story.active.is_done("baseline") and Story.active.is_done("duplicate") and not Story.active.is_done("isolate"), "only observed experiment objectives survive restart")
	var isolated := await probe("slow", false)
	check(int(isolated.get("created", 0)) == 1, "disabling retry isolates the cause")
	if not await wait_until(func() -> bool: return active("c02_03"), "controlled reproduction unlocks the fix"):
		return
	await wait_until(func() -> bool: return Story.active.data().has("policy_q"), "the policy question is offered before coding")
	await command("git switch -c fix/sequential-requests")
	var trust_before: Dictionary = Game.state["rel"].duplicate(true)
	check(Story.next_hint() != "", "the fix has a usable policy hint")
	check(Game.state["rel"] == trust_before, "asking for a hint does not lower trust")
	await command("npm test")
	check(not Story.active.is_done("tests"), "actual public tests reject the original module")
	var run_count: int = RequestLab.state()["runs"].size()
	await edit("export async function createOrder(request, store) { const order = await store.create(request); return { ...order, id: 42 }; }\n")
	var malformed := await RequestLab.run_probe({"network": "slow", "retry": true, "keys": "same", "clicks": 1, "version": "current"})
	check(not malformed.get("ok", false) and RequestLab.state()["runs"].size() == run_count, "a malformed player return value cannot contaminate experiment history")
	Game._save()
	check(Game.SaveStore._read_one(Game.SAVE_PATH, Game._default_state())["ok"], "an unsuccessful experiment does not break saving")
	var solution := Workspace.content("c02/request_sequential.ts")
	if _profile == "recover":
		# AICode drafts apply only to the file version they were built on: drop the broken edit first.
		await command("git restore src/orders/request.ts")
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		check(ai._on_delegate(true), "AICode applies its draft on the working branch")
		check(Game.stat("ai_used") == 1 and Workspace.read_file("src/orders/request.ts") == solution, "AI path writes the scoped sequential draft")
		ai.queue_free()
	else:
		await edit(solution)
		check(Game.stat("ai_used") == 0, "direct IDE path requires no AI use")
	var corrected := await probe("slow")
	check(int(corrected.get("created", 0)) == 1 and Story.active.is_done("verified"), "current code turns two calls into one order")
	await edit(solution + "\n// Revalidate this revision.\n")
	check(not Story.active.is_done("verified"), "editing invalidates verification of the previous revision")
	await probe("slow")
	var current_file := Workspace.read_file("src/orders/request.ts")
	var old := await probe("slow", true, "reported")
	check(int(old.get("created", 0)) == 2 and Workspace.read_file("src/orders/request.ts") == current_file, "reported baseline still reproduces without overwriting the fix")
	var distinct := await probe("slow", true, "current", "new")
	check(int(distinct.get("created", 0)) == 2, "separate request keys remain distinct purchases")
	await probe("slow")
	await lab_preview("fixed_" + Game.lang)
	await command("npm test")
	check(Story.active.is_done("tests"), "real local tests accept the sequential policy")
	check(Story.status("c02_03") == "active", "local experiments alone cannot complete the fix without a reviewed PR")
	await command("git add .")
	await command('git commit -m "fix: deduplicate sequential order retries"')
	await command("git push")
	var opened := await CodeHub.open_pr("fix/sequential-requests", "Fix sequential retries", "Reproduced delayed resend; verified the sequential contract. Concurrency and rollout pending.")
	check(opened.get("ok", false), "opened an actual remote PR")
	if not opened.get("ok", false):
		return
	var pr: Dictionary = opened["pr"]
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "CI and senior review merge the real fix"):
		print("C02_PR: ", JSON.stringify(pr))
		return
	check(pr["ci"]["state"] == "pass" and pr["ci"]["hidden"] == 1 and pr["review"]["state"] == "approved", "additional CI contract checks and senior approval passed")
	var paused := [0]
	var chapter_ended := [0]
	var on_pause := func() -> void: paused[0] += 1
	var on_end := func() -> void: chapter_ended[0] += 1
	Story.content_paused.connect(on_pause)
	Story.chapter_finished.connect(on_end)
	if not await wait_until(func() -> bool: return Game.state["day_done"], "finished the first chapter-two day"):
		return
	check(paused[0] == 0 and chapter_ended[0] == 0, "a mid-chapter day end claims neither pause nor completion")
	check(not Story.can_continue_chapter() and Game.state["monitor"]["status"]["api"] == "warn", "rollout is still pending after the sequential fix")
	var paid := Game.money()
	Game.next_day()
	check(Game.day() == 6 and Game.money() > paid and not Game.state["day_done"], "the next chapter-two day opens and pays once")
	Story.content_paused.disconnect(on_pause)
	Story.chapter_finished.disconnect(on_end)
	Game._save()


# --- Days 6-7: logs, screen states, concurrency, rollout, customer reply -------------------

const ANSWERS := {"c02_log": "minimal", "c02_states": "split", "c02_announce": "staged", "c02_retro": "rules", "c02_wrap": "note",
	"c02_ledger": "ticket", "c02_questions": "try", "c02_mira": "doc", "c02_pair": "pair", "c02_pair_check": "atomic"}


func _answer_for(key: String) -> String:
	match key:
		"c02_ask":
			return "direct" if _profile == "recover" else "narrow"
		"c02_policy_q":
			return "ask" if _profile == "recover" else "skip"
		"c02_payday":
			return "save" if _profile == "recover" else "desk"
	return ANSWERS.get(key, "")


func _process(_delta: float) -> void:
	if not _running:
		return
	for message in Game.state["chat"].duplicate():
		if message["answered"] == "" and not message["choices"].is_empty() and _answer_for(String(message["key"])) != "":
			Game.answer(int(message["id"]), _answer_for(String(message["key"])))
			return


func pr_by(id: int) -> Dictionary:
	return CodeHub.get_pr(id)


func ship(branch: String, title: String, body: String) -> Dictionary:
	await command("git add .")
	await command('git commit -m "%s"' % title)
	await command("git push")
	var opened := await CodeHub.open_pr(branch, title, body)
	check(opened.get("ok", false), "opened PR " + branch)
	return opened.get("pr", {})


func next_day_to(day: int) -> bool:
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day %d ends after its missions" % Game.day()):
		return false
	Game.next_day()
	Story.start_day(Game.day())
	check(Game.day() == day, "advanced to day %d" % day)
	return true


func finale() -> void:
	check(Game.day() == 6 and not Game.state["day_done"], "restart lands on the second chapter-two day")
	var chapter_ended := [0]
	var paused := [0]
	Story.chapter_finished.connect(func() -> void: chapter_ended[0] += 1)
	Story.content_paused.connect(func() -> void: paused[0] += 1)
	await Story.resume()
	# M04 - logs
	if not await wait_until(func() -> bool: return active("c02_04"), "logs task starts on day 6"):
		return
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync") and "...event" in Workspace.read_file("src/orders/request_log.ts"), "debug log module arrives via pull")
	await wait_until(func() -> bool: return Story.active.is_done("talk"), "agreed with Mina on what logs keep")
	await command("git switch -c fix/request-log")
	await command("npm test")
	check(not Story.active.is_done("logfix"), "public tests reject logging buyer data")
	await edit(Workspace.content("c02/request_log_fixed.ts"), "src/orders/request_log.ts")
	await command("npm test")
	check(Story.active.is_done("logfix"), "allowlisted log passes public tests")
	var log_pr := await ship("fix/request-log", "fix: keep only tracing fields in request logs", "Allowlist: requestId, shopId, result, attempt, retried, durationMs.")
	if log_pr.is_empty() or not await wait_until(func() -> bool: return log_pr["state"] == "merged", "log fix merged after hidden CI"):
		return
	check(int(log_pr["ci"]["hidden"]) >= 1, "log PR ran hidden CI checks")
	# M05 - screen states
	if not await wait_until(func() -> bool: return active("c02_05"), "screen-state review starts"):
		return
	var target := int(Story.active.data()["target"])
	check(pr_by(target)["flags"].get("needs_my_comment", false), "Sophie's PR asks for my review")
	CodeHub.submit_comments(target, "concern", [{"file": "src/orders/order_status.ts", "line": 21, "text": "      return { state: 'confirmed', orderId: response.orderId };"}], "")
	check(not Story.active.is_done("review"), "a concern on the wrong line does not count")
	pr_by(target)["flags"]["needs_my_comment"] = true
	if _profile == "recover":
		CodeHub.submit_comments(target, "lgtm", [], "")
	else:
		CodeHub.submit_comments(target, "concern", [{"file": "src/orders/order_status.ts", "line": 23, "text": "    case 'timeout':"}], "A timeout may already have an order; a new key defeats the server check.")
	check(Story.active.is_done("review") and Story.active.data().get("found_by", "") == ("mina" if _profile == "recover" else "me"), "review outcome depends on who found the bug")
	if not await wait_until(func() -> bool: return pr_by(target)["state"] == "merged", "Sophie's agreed fix merges"):
		print("C02_PR: ", JSON.stringify(pr_by(target)))
		return
	check(Game.state["flags"].get("c02_states_agreed", false), "agreed screen states recorded for the Wiki")
	if not await next_day_to(7):
		return
	check(Game.state["side"].has("c02_ledger") and Game.state["side"].has("c02_questions") and Game.state["side"].has("c02_payday"), "day-6 side events happened")
	if _profile == "recover":
		check(Game.state["flags"].get("c02_payday", "") == "save" and not Game.state["owned"].has("plant_big"), "saving the paycheck buys nothing")
	else:
		check(Game.state["owned"].has("plant_big"), "the first paycheck puts a plant on the desk")
	# M06 - concurrency
	if not await wait_until(func() -> bool: return active("c02_06"), "concurrency task starts on day 7"):
		return
	await command("git switch main")
	await command("git pull")
	check(Story.active.is_done("sync"), "concurrency tests arrive via pull")
	var seq := await probe("slow", true, "current", "same", "sequential")
	check(int(seq.get("created", 0)) == 1, "sequential fix still holds for sequential calls")
	var race := await probe("slow", true, "current", "same", "concurrent")
	check(int(race.get("created", 0)) == 2 and Story.active.is_done("repro"), "overlapping calls reproduce duplicates")
	await lab_preview("concurrent_" + Game.lang)
	await command("git switch -c fix/concurrent-requests")
	await command("npm test")
	check(not Story.active.is_done("concfix"), "check-then-create fails the concurrency tests")
	var reference := Workspace.content("c02/request_concurrent.ts")
	var conc_pr := {}
	if _profile == "recover":
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		check(ai._on_delegate(true), "AICode applies its draft on the working branch")
		ai.queue_free()
		await command("npm test")
		check(Story.active.is_done("concfix"), "AI draft passes the public tests")
		conc_pr = await ship("fix/concurrent-requests", "fix: claim request keys atomically", "Claim/complete/release for concurrent calls.")
		if conc_pr.is_empty() or not await wait_until(func() -> bool: return conc_pr["ci"]["state"] == "fail", "hidden CI catches the pending conflict gap"):
			return
		await edit(reference)
		await command("git add .")
		await command('git commit -m "fix: compare fingerprints while pending"')
		await command("git push")
	else:
		await edit(reference)
		await command("npm test")
		check(Story.active.is_done("concfix"), "atomic claim passes the public tests")
		conc_pr = await ship("fix/concurrent-requests", "fix: claim request keys atomically", "Covers concurrent calls, retry after a failed create, and conflicting contents while pending.")
	if conc_pr.is_empty() or not await wait_until(func() -> bool: return conc_pr["state"] == "merged", "concurrency fix merged"):
		print("C02_PR: ", JSON.stringify(conc_pr))
		return
	if _profile == "recover":
		var c06 = Story.mission("c02_06")
		check(c06.data().get("pair", "") == "pair" and c06.data().get("pair_explained", false), "a stalled player pairs with Daniel and explains the fix")
	var fixed := await probe("slow", true, "current", "same", "concurrent")
	check(int(fixed.get("created", 0)) == 1, "current code turns overlapping calls into one order")
	# M07 - rollout
	if not await wait_until(func() -> bool: return active("c02_07"), "rollout task starts"):
		return
	var monitor := preload("res://scripts/apps/monitor_app.gd").new()
	monitor.theme = UITheme.build()
	monitor.position = Vector2(40, 40)
	monitor.size = Vector2(900, 600)
	add_child(monitor)
	var m = Story.active
	await wait_until(func() -> bool: return m.is_done("announce"), "agreed with Alex on the announcement")
	m.apply("all")
	check(m.rollout()["scope"] == "" and not m.is_done("scope"), "rolling out to every shop is refused")
	m.apply("moonlight")
	m.observe()
	m.choose_evidence("quiet")
	check(not m.is_done("evidence"), "an empty window is not evidence")
	if _profile == "recover":
		m.roll_back()
		check(not m.is_done("scope") and int(m.rollout()["rollbacks"]) == 1, "rolling back resets the observation")
		m.apply("moonlight")
		m.observe()
	m.choose_evidence("traffic")
	m.record("", "")
	check(not m.is_done("record"), "recording needs a time and an owner")
	await get_tree().process_frame
	await capture("rollout_" + Game.lang)
	m.record(Game.L("내일 10:00", "Tomorrow 10:00"), Game.pname())
	if not await wait_until(func() -> bool: return active("c02_08"), "rollout recorded and observed"):
		return
	monitor.queue_free()
	check(Game.state["monitor"]["status"]["api"] == "ok", "monitor returns to normal after the rollout")
	# M08 - customer reply
	var reply = Story.active
	var notes: Array = reply.submit({"change": "jargon", "verified": "all", "existing": "omit", "contact": "devteam"})
	check(notes.size() == 4 and not reply.reply_state()["sent"], "Yuri rejects jargon, overclaiming and a missing follow-up")
	await lab_preview("reply_" + Game.lang)
	notes = reply.submit({"change": "plain", "verified": "scoped", "existing": "follow", "contact": "support"})
	check(notes.is_empty() and reply.reply_state()["sent"] and reply.is_done("sent"), "the scoped plain-language reply is sent")
	if not await wait_until(func() -> bool: return Game.state["day_done"], "the chapter's last day ends"):
		return
	check(chapter_ended[0] == 1 and paused[0] == 0, "Chapter 2 reports completion exactly once")
	check(Story.chapter_missions(2).all(func(x) -> bool: return Story.status(x.id) == "done"), "all eight chapter-two tasks are done")
	check(Game.state["issues"].any(func(i: Dictionary) -> bool: return i["id"] == "LEGACY-17"), "LEGACY-17 teaser is filed")
	check(Game.state["side"].has("c02_mira"), "day-7 side event happened")
	check(Game.state["flags"].get("c02_wrap", "") == "note", "wrap-up choice recorded")
	check(Story.can_continue_chapter(), "Chapter 3 is offered after Chapter 2")
	var rewards: Dictionary = Game.state["rel"].duplicate(true)
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._chapter_done and Game.state["rel"] == rewards, "completed chapter resumes without duplicate rewards")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter2_ending_" + Game.lang)
	var paid := Game.money()
	check(not Game.claim_salary() and Game.money() == paid, "ending cannot duplicate salary")
	_desktop.queue_free()
	Game._save()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER2_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
