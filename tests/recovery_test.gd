extends Node
## Real process restart at an unfinished introduction, plus independent file recovery cases.

const Store := preload("res://scripts/services/save_store.gd")
var _checks := 0
var _failures := 0
var _stage := "before"


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func write_raw(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if "--stage" in args:
		_stage = args[args.find("--stage") + 1]
	if _stage == "before":
		Game.reset_state()
		Game.state["player_name"] = "Saved Developer"
		var prepared := await Workspace.prepare()
		check(prepared["ok"], "isolated workspace prepared")
		Engine.time_scale = 0.0
		Story.start_new()
		check(not Game.state["chat"].any(func(m: Dictionary) -> bool: return m["key"] == "d1_hello"), "checkpoint precedes the first delayed choice")
		Game._save()
		await finish()
		return
	Engine.time_scale = 8.0
	check(Game.load_game(), "loaded the previous process's checkpoint")
	check((await Workspace.prepare())["ok"], "mounted the previous process's Git workspace")
	await Story.resume()
	check(Game.pending_choice("d1_hello"), "the missing welcome choice is restored after process restart")
	var welcome_count: int = Game.state["chat"].filter(func(m: Dictionary) -> bool: return m["key"] == "d1_hello").size()
	await Story.resume()
	check(Game.state["chat"].filter(func(m: Dictionary) -> bool: return m["key"] == "d1_hello").size() == welcome_count, "repeated resume does not duplicate a choice")
	var identity: Dictionary = Story.active.objectives.filter(func(o: Dictionary) -> bool: return o["id"] == "identity")[0]
	check("Saved Developer" in identity["guide"]["ko"] and not "%s" in identity["guide"]["en"], "name-dependent tutorial guides survive resume")
	var original_repo := Workspace.repo
	Workspace.repo = Workspace.root.path_join("missing-repo")
	var desktop := preload("res://scripts/desktop/desktop.gd").new()
	add_child(desktop)
	desktop.boot()
	await get_tree().create_timer(0.05, true, false, true).timeout
	check("기존 파일은 유지" in desktop._boot_log.text and Game.has_save(), "missing repository stops boot without silently resetting saved progress")
	Workspace.repo = original_repo
	desktop.queue_free()
	await get_tree().process_frame
	Story.active = null
	for argv in [["config", "user.name", "Recovery Developer"], ["config", "user.email", "recovery@example.invalid"], ["switch", "-c", "qa/history"]]:
		check((await Workspace.git(argv))["code"] == 0, "prepare real checkout history")
	check(Workspace.write_file("history_marker.txt", "committed evidence"), "create isolated history fixture")
	check((await Workspace.git(["add", "."]))["code"] == 0, "stage real history fixture")
	check((await Workspace.git(["commit", "-m", "test: one actual commit"]))["code"] == 0, "create one actual player commit")
	var commits_before := Game.stat("commits")
	await Workspace.git(["switch", "main"])
	Workspace._seen_commits.clear()  # Same in-memory cache state as a fresh process.
	await Workspace.git(["switch", "qa/history"])
	check(Game.stat("commits") == commits_before, "checking out old work after restart cannot fabricate a new commit")
	check(Workspace.write_file("uncommitted.txt", "preserve my work"), "create uncommitted player work")
	Game._save()
	check((await Workspace._git_in(Workspace.repo, ["switch", "main"]))["code"] == 0, "simulate an external branch change after saving")
	await Workspace.prepare()
	check(Workspace.restore_changed and Workspace.branch == "main", "checkpoint mismatch is detected without rewinding Git")
	check(Workspace.read_file("uncommitted.txt") == "preserve my work", "mounting a changed workspace preserves uncommitted files")
	var defaults: Dictionary = Game._default_state()
	var dir := "user://qa_saves"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir.path_join("save.json")
	var first := defaults.duplicate(true)
	check(Store.write(path, first, defaults), "initial versioned save is written")
	var second := first.duplicate(true)
	second["day"] = 2
	check(Store.write(path, second, defaults), "new save retains the previous generation")
	check(Store.read(path, defaults)["data"]["day"] == 2, "latest valid state is loaded")
	write_raw(path, "{ interrupted write")
	var recovered := Store.read(path, defaults)
	check(recovered["ok"] and recovered.get("recovered", false) and recovered["data"]["day"] == 1, "corrupt primary recovers the valid previous generation")
	check(Store.write(path, second, defaults), "recovered state can be written without destroying the backup")
	check(FileAccess.file_exists(path + ".corrupt"), "corrupt original is retained for inspection")
	check(Store._read_one(path + ".bak", defaults)["data"]["day"] == 1, "corrupt primary never replaces a valid backup")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "simulate interruption between backup and rename in isolated files")
	check(Store.read(path, defaults)["ok"], "missing primary still recovers the backup")
	var legacy := first.duplicate(true)
	legacy.erase("save_version")
	legacy.erase("investigations")
	legacy["rel"] = {"daniel": {"tech": 33}}
	write_raw(path, JSON.stringify(legacy))
	var migrated := Store.read(path, defaults)
	check(migrated["ok"] and migrated["data"]["save_version"] == Store.VERSION, "legacy version zero is migrated")
	check(migrated["data"]["rel"]["daniel"]["tech"] == 33 and migrated["data"]["rel"]["daniel"].has("work") and migrated["data"].has("investigations"), "migration preserves values and fills nested defaults")
	var future := first.duplicate(true)
	future["save_version"] = Store.VERSION + 1
	var future_text := JSON.stringify(future)
	write_raw(path, future_text)
	check(Store.read(path, defaults)["error"] == "newer_version", "newer versions are not silently replaced by an older backup")
	check(not Store.write(path, first, defaults) and FileAccess.get_file_as_string(path) == future_text, "writing cannot overwrite a newer-version primary")
	for invalid in [{"day": "2", "story": {}}, {"day": 1, "story": {"m": {"status": "active", "obj": []}}}, {"day": 1, "story": {}, "rank": 50}, {"day": 1, "story": {}, "minutes": true}]:
		write_raw(path, JSON.stringify(invalid))
		check(not Store._read_one(path, defaults)["ok"], "invalid state shape is rejected")
	# The previous completed day cannot be paid twice by repeated transitions.
	Game.state["day_done"] = true
	var money := Game.money()
	Game.next_day()
	var paid := Game.money()
	Game.next_day()
	check(paid > money and Game.money() == paid and Game.day() == 2, "double transition cannot duplicate a salary")
	Game.state["day_done"] = true
	check(Game.claim_salary(), "completed day's salary can be claimed")
	var claimed := Game.money()
	check(not Game.claim_salary() and Game.money() == claimed, "ending re-entry cannot pay the same day twice")
	# Resume a saved merge after rewards were applied but before the closing dialogue ended.
	Game.reset_state()
	Game.state_reset.emit()
	Game.state["day"] = 2
	var merged_pr := CodeHub._new_pr("me", "fix/saved", "Saved merge", "", "daniel")
	merged_pr["state"] = "merged"
	Game.state["story"]["d2_04"] = {"status": "active", "obj": {"merged": true}, "data": {"pr": merged_pr["id"], "_merge_reward": true, "_intro_complete": true}}
	Game.state["story"]["d2_05"] = {"status": "skipped", "obj": {}, "data": {}}
	var before_rewards: Dictionary = Game.state["rel"].duplicate(true)
	await Story.resume()
	await get_tree().create_timer(0.7, true, false, true).timeout
	check(Story.status("d2_04") == "done", "saved post-merge dialogue reaches mission completion")
	check(Game.state["rel"] == before_rewards, "resuming post-merge dialogue does not grant rewards twice")
	# Resume between the retrospective answer and the performance-review prompt.
	Game.reset_state()
	Game.state_reset.emit()
	Game.state["day"] = 4
	Game.state["story"]["d4_08"] = {"status": "done", "obj": {}, "data": {}}
	Game.state["story"]["d4_09"] = {"status": "skipped", "obj": {}, "data": {}}
	Game.state["story"]["d4_10"] = {"status": "active", "obj": {"retro": true}, "data": {"_intro_complete": true}}
	await Story.resume()
	check(Game.pending_choice("d4_review"), "performance review prompt resumes after an interrupted retro")
	for message in Game.state["chat"]:
		if message["key"] == "d4_review":
			Game.answer(int(message["id"]), "thanks")
	var finish_deadline := Time.get_ticks_msec() + 3000
	while not Game.state["day_done"] and Time.get_ticks_msec() < finish_deadline:
		await get_tree().process_frame
	check(Story.status("d4_10") == "done" and Game.state["day_done"], "resumed performance review finishes the chapter")
	var chapter_events := [0]
	var on_chapter := func() -> void: chapter_events[0] += 1
	Story.chapter_finished.connect(on_chapter)
	await Story.resume()
	check(chapter_events[0] == 1 and Game.day() == 4, "loading a completed chapter restores the ending instead of an extra work day")
	Story.chapter_finished.disconnect(on_chapter)
	# A new game cancels the old mission's delayed dialogue.
	Engine.time_scale = 0.0
	Story.active = null
	Game.reset_state()
	Game.state_reset.emit()
	Game.state["player_name"] = "Abandoned Developer"
	Story.start_new()
	Game.reset_state()
	Game.state_reset.emit()
	Game.state["player_name"] = "Current Developer"
	Story.start_new()
	Engine.time_scale = 8.0
	await get_tree().create_timer(0.4, true, false, true).timeout
	check(not Game.state["chat"].any(func(m: Dictionary) -> bool: return "Abandoned Developer" in Game.tx(m["text"])), "abandoned mission coroutines do not post into a new game")
	check(Game.state["chat"].filter(func(m: Dictionary) -> bool: return m["key"] == "d1_hello").size() == 1, "only the current introduction remains")
	await finish()


func finish() -> void:
	while Sfx._music.stream == null:
		await get_tree().process_frame
	Game._save()
	Sfx.stop_all()
	await get_tree().create_timer(0.1, true, false, true).timeout
	print("RECOVERY_QA: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
