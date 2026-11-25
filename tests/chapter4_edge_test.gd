extends Node
## Regression suite for the Chapter 4 QA review:
## P1 resume stalls (pilot result, last answer), P1 merging without characterization tests,
## P2 Pork Git author evidence, Docs gating and narrow width, corrected time-zone rows,
## choice-consistent follow-ups (status quo, review rotation), ATLAS results page, Docs archive.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DocsApp := preload("res://scripts/apps/docs_app.gd")
const AtlasView := preload("res://scripts/apps/atlas_view.gd")
const LaunchStore := preload("res://scripts/apps/launch_store_view.gd")
const PageView := preload("res://scripts/apps/page_view.gd")
var _checks := 0
var _failures := 0
var _terminal: Control
var _ide: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("C04EDGE_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func wait_until(predicate: Callable, label: String, seconds := 45.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok := bool(predicate.call())
	check(ok, label)
	return ok


func active(id: String) -> bool:
	return Story.active != null and Story.active.id == id and Story.status(id) == "active" and Story.active.data().get("_intro_complete", false)


func command(line: String) -> void:
	await _terminal._execute(_terminal.tokenize(line))


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func said(fragment: String) -> bool:
	return Game.state["chat"].any(func(m: Dictionary) -> bool: return fragment in Game.tx(m["text"]))


func mark_done(ids: Array) -> void:
	for id in ids:
		Game.state["story"][id] = {"status": "done", "obj": {}, "data": {}}


## Simulates quitting and reopening: save, then rebuild missions from the save.
func reload() -> void:
	Game._save()
	check(Game.load_game(), "reloaded the save")
	await Story.resume()


func answer(key: String, option: String) -> void:
	for m in Game.state["chat"]:
		if m["key"] == key and m["answered"] == "":
			Game.answer(int(m["id"]), option)
			return


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.reset_state()
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	await command('git config user.name "Edge Tester"')
	await command("git config user.email edge@example.invalid")
	Game.state["player_name"] = "Edge Tester"
	Game.state["rank"] = 2
	for chapter in [1, 2, 3]:
		mark_done(Story.chapter_missions(chapter).map(func(m) -> String: return m.id))
	Game.state["day"] = 11
	await Story.resume()
	await legacy_without_tests()
	await author_evidence()
	await status_quo_day()
	await atlas_page()
	await docs_archive()
	await launch_store()
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("CHAPTER4_EDGE_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)


# P1 · a PR that only deletes the legacy branch must not finish the task.
func legacy_without_tests() -> void:
	if not await wait_until(func() -> bool: return active("c04_01"), "the legacy task starts"):
		return
	await command("git switch main")
	await command("git pull")
	await command("git switch -c chore/remove-legacy")
	_ide.open_file("src/refunds/refund.ts")
	_ide._code.text = Workspace.content("c04/refund_mutant.ts")
	_ide.save()
	await command("git add .")
	await command('git commit -m "chore: remove unused legacy branch"')
	await command("git push")
	var opened := await CodeHub.open_pr("chore/remove-legacy", "chore: remove legacy branch", "Nobody uses it.")
	var pr: Dictionary = opened.get("pr", {})
	if not await wait_until(func() -> bool: return not pr.is_empty() and pr["ci"]["state"] in ["pass", "fail"], "CI runs on the deletion PR"):
		return
	check(pr["ci"]["state"] == "fail", "hidden CI catches the deleted legacy behavior")
	await get_tree().create_timer(1.0, true, false, true).timeout
	check(pr["state"] == "open" and Story.status("c04_01") == "active", "the deletion PR doesn't merge or finish the task")
	check(not Story.active.is_done("pinned") and not Story.active.is_done("plan"), "the task still needs tests and a plan")
	# Even with green CI, Daniel asks for the tests first.
	Story.active.review(pr)
	await wait_until(func() -> bool: return pr["review"]["state"] == "changes", "Daniel requests changes without characterization tests")
	await command("git switch main")


# P2 · Pork Git evidence counts; Docs questions wait for it.
func author_evidence() -> void:
	mark_done(["c04_01"])
	await Story.resume()
	if not await wait_until(func() -> bool: return active("c04_02"), "the author task starts"):
		return
	var m = Story.active
	check(m.open_forms().is_empty(), "Docs questions stay closed before the author is found")
	check(m.submit_form("questions", {"q": ["context", "temporary", "changed"]}).size() == 1 and Story.status("c04_02") == "active", "submitting questions early doesn't finish the task")
	var pork := preload("res://scripts/apps/pork_app.gd").new()
	pork.theme = UITheme.build()
	add_child(pork)
	await pork._refresh()
	pork._tabs.current_tab = 1
	var found := -1
	for i in pork._history.item_count:
		if "partial refunds" in pork._history.get_item_text(i):
			found = i
	check(found >= 0, "Pork Git lists Daniel's refund commit")
	if found >= 0:
		pork._history.select(found)
		await pork._show_selection(1)
	await wait_until(func() -> bool: return m.is_done("found"), "opening Daniel's commit in Pork Git finds the author", 10.0)
	pork.queue_free()
	check(not m.open_forms().is_empty(), "the questions open after the author is found")


# Status quo, resume stalls, review rotation lines, narrow Docs.
func status_quo_day() -> void:
	mark_done(["c04_02", "c04_03", "c04_04"])
	Game.state["story"]["c04_05"] = {"status": "done", "obj": {}, "data": {"forms": {"decision": {"scope": "status_quo", "rollback": "flag", "evidence": ["recon"]}}}}
	Game.state["flags"]["c04_scope"] = "status_quo"
	Game.state["day"] = 13
	Game.state["minutes"] = 10 * 60 + 50
	Game.state["day_done"] = false
	await Story.resume()
	if not await wait_until(func() -> bool: return active("c04_06"), "the pilot task starts after a status-quo decision"):
		return
	var m = Story.active
	check(said("손으로 대조하는 절차"), "a status-quo decision turns the pilot into manual reconciliation")
	# Narrow Docs window.
	var docs := DocsApp.new()
	docs.theme = UITheme.build()
	docs.position = Vector2(20, 20)
	docs.size = Vector2(430, 560)
	add_child(docs)
	await get_tree().process_frame
	await get_tree().process_frame
	var overflow := docs.find_children("*", "CheckBox", true, false).filter(func(b: Control) -> bool: return b.get_global_rect().end.x > docs.get_global_rect().end.x + 1.0)
	check(overflow.is_empty(), "every Docs option fits a 430px window")
	await capture("docs_narrow_430")
	docs.queue_free()
	# P1 · reload right after submitting the pilot.
	check(m.submit_form("pilot", {"seller": "mosaic", "bar": "zero"}).is_empty(), "the pilot is submitted")
	await reload()
	await wait_until(func() -> bool: return Story.status("c04_06") == "done", "after a reload the pilot result still arrives")
	check(int(Game.state["flags"].get("c04_manual_hours", 0)) == 6, "the manual pilot records the weekly hours")
	if not await wait_until(func() -> bool: return active("c04_07"), "review-load task starts"):
		return
	check(Story.active.submit_form("rotation", {"fix": ["slots", "small"]}).is_empty(), "a rotation without training is accepted")
	check(said("11시와 4시") and not said("짝 리뷰 첫 짝"), "Daniel describes the chosen review slots and doesn't invite a pair review")
	# P1 · reload right after the last answer.
	if not await wait_until(func() -> bool: return active("c04_08"), "decision record starts"):
		return
	await wait_until(func() -> bool: return Game.pending_choice("q_finance"), "the first question arrives")
	answer("q_finance", "owner")
	await wait_until(func() -> bool: return Game.pending_choice("q_support"), "the second question arrives")
	answer("q_support", "know")
	await wait_until(func() -> bool: return Game.pending_choice("q_platform"), "the third question arrives")
	answer("q_platform", "owner")
	await reload()
	await wait_until(func() -> bool: return Story.status("c04_08") == "done" and Game.state["day_done"], "after a reload the decision record is approved and the day ends")
	check(said("현상 유지와 매주 수동 대조"), "the approval matches the status-quo decision")


# Buyer wish · see your fix working: the ATLAS page runs the repository's code.
func atlas_page() -> void:
	Workspace.write_file("src/atlas/dual_write.ts", Workspace.content("c04/dual_write.ts"))
	var view := AtlasView.new()
	view.theme = UITheme.build()
	view.position = Vector2(20, 20)
	view.size = Vector2(900, 600)
	add_child(view)
	var before: Dictionary = await view.run()
	check((before.get("missing", []) as Array).size() == 3 and (before.get("retry", []) as Array).is_empty(), "the original code silently loses the three outage refunds")
	Workspace.write_file("src/atlas/dual_write.ts", Workspace.content("c04/dual_write_fixed.ts"))
	var after: Dictionary = await view.run()
	check((after.get("missing", []) as Array).is_empty() and (after.get("retry", []) as Array).size() == 3, "the fixed code queues all three for retry")
	await capture("atlas_page")
	view.queue_free()


# Buyer wish · documents stay with comments.
func docs_archive() -> void:
	var past: Array = DocsApp.archive()
	var decision: Array = past.filter(func(d: Dictionary) -> bool: return d["key"] == "c04_05:decision")
	check(not decision.is_empty() and (decision[0]["comments"] as Array).size() >= 1, "the decision document is in the archive with the finance comment")
	check(past.any(func(d: Dictionary) -> bool: return d["key"] == "c04_06:pilot" and not (d["comments"] as Array).is_empty()), "the pilot document keeps Mina's result")
	var docs := DocsApp.new()
	docs.theme = UITheme.build()
	docs.position = Vector2(20, 20)
	docs.size = Vector2(820, 600)
	add_child(docs)
	await get_tree().process_frame
	for b in docs.find_children("*", "Button", true, false):
		if b.text in ["열기", "Open"]:
			b.pressed.emit()
			break
	await get_tree().process_frame
	await capture("docs_archive")
	docs.queue_free()


# Buyer wish · after the Chapter 3 launch, moonlight.shop is the customer's store running my code.
func launch_store() -> void:
	for name in ["deadline", "cancel", "labels"]:
		Workspace.write_file("src/preorder/%s.ts" % name, Workspace.content("c03/%s.ts" % name))
	Game.state["flags"]["c03_released"] = true
	var page := PageView.new()
	page.theme = UITheme.build()
	add_child(page)
	await get_tree().process_frame
	check(page.store != null, "moonlight.shop shows the pre-order store after the launch instead of a 404")
	page.queue_free()
	var store := LaunchStore.new()
	store.theme = UITheme.build()
	store.position = Vector2(20, 20)
	store.size = Vector2(900, 640)
	add_child(store)
	var buggy: Dictionary = await store.load_store()
	check(buggy.get("deadline", {}).get("after", false) == true, "with the original code orders stay open after the deadline")
	check(String(store.cancel("P-102").get("state", "")) == "cancelled", "with the original code a paid cancel skips the refund request")
	for name in ["deadline", "cancel", "labels"]:
		Workspace.write_file("src/preorder/%s.ts" % name, Workspace.content("c03/%s_fixed.ts" % name))
	store.cancelled.clear()
	var fixed: Dictionary = await store.load_store()
	store.set_moment("at")
	check(not store.open_now() and not store.reserve(), "with the fixed code the deadline minute is closed for customers")
	store.set_moment("before")
	check(store.reserve(), "a minute before the deadline a customer can pre-order")
	check(String(store.cancel("P-102").get("state", "")) == "refund_requested" and String(store.cancel("P-103").get("state", "")) == "needs_review", "cancel requests follow the agreed policy")
	check("발송" in String(fixed.get("labels", "")), "the product shows the ship-by wording")
	await get_tree().process_frame
	await capture("launch_store")
	store.queue_free()
