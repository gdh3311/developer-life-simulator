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


func edit(content: String) -> void:
	_ide.open_file("src/orders/request.ts")
	_ide._code.text = content
	_ide.save()
	await get_tree().create_timer(0.1, true, false, true).timeout


func probe(network: String, retry := true, version := "current", keys := "same") -> Dictionary:
	var result := await RequestLab.run_probe({"network": network, "retry": retry, "keys": keys, "clicks": 1, "version": version})
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
	if _stage == "after":
		check(Game.load_game(), "loaded the previous process's reproduction checkpoint")
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	if _stage == "before":
		await before_restart()
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
	check(Story.chapter_missions(1).size() == 10 and Story.chapter_missions(2).size() == 3, "chapter progress counts are separated")
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
		var ai := preload("res://scripts/apps/ai_app.gd").new()
		add_child(ai)
		await ai._on_delegate()
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
	if not await wait_until(func() -> bool: return Game.state["day_done"], "completed all three available tasks"):
		return
	check(paused[0] == 1 and chapter_ended[0] == 0, "partial content never claims a completed chapter")
	check(not Story.can_continue_chapter() and Game.state["monitor"]["status"]["api"] == "warn", "rollout is still pending; no empty next chapter is offered")
	Game.next_day()
	check(Game.day() == 5, "cannot advance to an unimplemented day")
	var rewards: Dictionary = Game.state["rel"].duplicate(true)
	_desktop = Desktop.new()
	_desktop.theme = UITheme.build()
	_desktop.size = Vector2(1000, 700)
	add_child(_desktop)
	_desktop._boot.visible = false
	await Story.resume()
	check(_desktop._content_done and Game.state["rel"] == rewards, "completed slice resumes without duplicate rewards")
	_desktop._show_day_summary()
	_desktop._on_next_day()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await capture("chapter2_segment_" + Game.lang)
	var paid := Game.money()
	check(not Game.claim_salary() and Game.money() == paid, "slice summary cannot duplicate salary")
	_desktop.queue_free()
	Story.content_paused.disconnect(on_pause)
	Story.chapter_finished.disconnect(on_end)
	Game._save()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER2_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
