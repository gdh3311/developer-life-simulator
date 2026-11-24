extends Node
## Run through tools/run_gameplay_tests.ps1, which creates an isolated project and save area.

const BaseMission := preload("res://scripts/story/mission.gd")
const CaseFiles := preload("res://scripts/story/case_files.gd")
const TaskBoard := preload("res://scripts/apps/tasks_app.gd")
const Dashboard := preload("res://scripts/apps/dashboard_app.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

class NavigationSpy extends Control:
	var opened: Array = []
	func open_resource(app: String, target: String) -> void:
		opened.append([app, target])

var _failed := 0
var _checks := 0
var root: Window:
	get:
		return get_tree().root


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(description)


func activate(id: String) -> void:
	var m := BaseMission.new()
	m.id = id
	m.title = {"ko": "테스트 업무", "en": "Test task"}
	m.story = Story
	Game.state["story"][id] = {"status": "active", "obj": {}, "data": {}}
	Story.active = m


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		push_error("Use the isolated test runner; do not run against a player's save.")
		get_tree().quit(2)
		return
	Game.reset_state()
	root.content_scale_size = Vector2i(1000, 640)
	root.size = Vector2i(1000, 640)
	RenderingServer.set_default_clear_color(UITheme.BG0)
	var definitions := CaseFiles.definitions()
	check(definitions.size() == 6, "Six investigation cases are defined")
	for id in definitions:
		var file: Dictionary = definitions[id]
		var choices: Array = file["hypotheses"].map(func(h: Dictionary) -> String: return h["id"])
		check(choices.size() == 3 and choices.count(file["answer"]) == 1, id + ": exactly one valid explanation")
		for c in file["clues"]:
			check(c["title"].has("ko") and c["title"].has("en") and c["detail"].has("en"), id + ": bilingual clue")
	activate("d2_04")
	check(not Cases.choose("d2_04", "optional"), "A hypothesis needs an observed clue")
	Game.emit_event("wiki_page", {"page": "shipping"})
	check(Cases.record("d2_04").is_empty(), "Unrelated Wiki pages do not earn clues")
	Game.emit_event("tests", {"ok": false, "failed": 0})
	check(Cases.record("d2_04").is_empty(), "Runtime errors are not fabricated failing reproductions")
	Game.emit_event("wiki_page", {"page": "names"})
	Game.emit_event("wiki_page", {"page": "names"})
	check(Cases.record("d2_04")["clues"].size() == 1, "Repeated observations do not duplicate clues")
	check(not Cases.choose("d2_04", "invented"), "Unknown hypothesis IDs are rejected")
	var trust_before: Dictionary = Game.state["rel"].duplicate(true)
	check(Cases.choose("d2_04", "cache"), "An incorrect hypothesis can be recorded")
	check(Cases.choose("d2_04", "optional"), "A hypothesis can be revised")
	check(Game.state["rel"] == trust_before, "Hypothesis experiments do not change trust")
	check(Game.state["story"]["d2_04"]["obj"].is_empty(), "Selecting a hypothesis does not complete actual objectives")
	Game.emit_event("code_viewed", {"path": "src/users/displayName.ts"})
	Game.emit_event("tests", {"ok": false, "failed": 1})
	check(Cases.record("d2_04")["clues"].size() == 3, "Code views and real test failures add relevant evidence")
	check(Game.state["rel"] == trust_before, "Local experiment failures do not reduce trust")
	Cases.close_case("d2_04")
	Cases.close_case("d2_04")
	check(Cases.archive().size() == 1, "Repeated completion creates one archive entry")
	check(not Cases.choose("d2_04", "cache"), "Completed notes cannot rewrite the original hypothesis")
	activate("d2_05")
	Game.emit_event("cmd", {"argv": ["git", "blame", "src/users/displayName.ts"]})
	Game.emit_event("command_finished", {"argv": ["git", "blame"], "code": 1, "out": "displayName"})
	check(Cases.record("d2_05").is_empty(), "Typing or failing a Git command does not fabricate history evidence")
	Game.emit_event("command_finished", {"argv": ["git", "log"], "code": 0, "out": "unrelated history"})
	check(Cases.record("d2_05").is_empty(), "Unrelated successful Git history is not evidence")
	Game.emit_event("command_finished", {"argv": ["git", "blame"], "code": 0, "out": "getDisplayName(user)"})
	check(Cases.record("d2_05").get("clues", {}).has("history"), "Successful relevant history is recorded")
	activate("d3_06")
	Game.emit_event("pr_diff_viewed", {"mission": "other", "text": "coupon"})
	check(Cases.record("d3_06").is_empty(), "Another mission's diff is not evidence")
	Game.emit_event("pr_diff_viewed", {"mission": "d3_06", "text": ""})
	check(Cases.record("d3_06").is_empty(), "An unloaded diff is not evidence")
	Game.emit_event("pr_diff_viewed", {"mission": "d3_06", "text": "+++ b/src/orders/coupon.ts"})
	check(Cases.record("d3_06").get("clues", {}).has("diff"), "Loaded relevant PR changes are evidence")
	Game.state["flags"]["coupon_bug"] = true
	Cases.close_case("d3_06")
	check(Cases.record("d3_06")["outcome"] == "followup", "Missed review is not labelled a resolved bug")
	activate("d4_09")
	Cases.close_case("d4_09")
	check(Cases.record("d3_06")["outcome"] == "recovered", "A later hotfix records recovery")
	activate("d3_07")
	CodeHub.prs().append({"id": 900, "mission": "other"})
	CodeHub.prs().append({"id": 901, "mission": "d3_07"})
	Cases._observe("mergeable", {"pr": 900, "conflict": true})
	check(Cases.record("d3_07").is_empty(), "Another PR's conflict is not evidence")
	Cases._observe("mergeable", {"pr": 901, "conflict": true})
	check(Cases.record("d3_07").get("clues", {}).has("conflict"), "The current mission's real conflict is evidence")
	Game.state["story"]["d3_07"]["status"] = "done"
	Cases._observe("wiki_page", {"page": "shipping"})
	check(not Cases.record("d3_07")["clues"].has("policy"), "Late events cannot change a completed mission")
	activate("d4_08")
	Game.emit_event("monitor_viewed", {"mode": "normal"})
	check(Cases.record("d4_08").is_empty(), "Normal logs do not prove an auth outage")
	var monitor := preload("res://scripts/apps/monitor_app.gd").new()
	monitor._rng.seed = 1
	Game.state["monitor"]["mode"] = "auth_down"
	root.add_child(monitor)
	check(Cases.record("d4_08").get("clues", {}).has("logs"), "The actual Monitor records a displayed incident log")
	monitor.queue_free()
	Game.emit_event("wiki_page", {"page": "auth"})
	Cases.choose("d4_08", "timeout")
	# JSON stores all numeric fields as floats; compare the persisted representation.
	var expected: Dictionary = JSON.parse_string(JSON.stringify(Game.state["investigations"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://sandbox"))
	Game._save()
	Game.reset_state()
	check(Game.load_game(), "Isolated save reloads")
	check(Game.state["investigations"] == expected, "Clues, revised hypotheses, outcomes and archive survive save/reload")
	Game.state.erase("investigations")
	check(Cases.record("d4_08").is_empty() and Cases.archive().is_empty(), "Legacy saves without investigation data remain valid")
	Game.emit_event("wiki_page", {"page": "auth"})
	check(Cases.record("d4_08").get("clues", {}).has("policy"), "Old saves acquire new notes lazily")
	Game.state["investigations"] = expected
	Story.active = Story.mission("d4_08")
	# Instantiate both languages, including the live observer callbacks and tab layout.
	for language in ["ko", "en"]:
		Game.lang = language
		var spy := NavigationSpy.new()
		root.add_child(spy)
		var board := TaskBoard.new()
		board.desktop = spy
		board.theme = UITheme.build()
		board.position = Vector2(20, 20)
		board.size = Vector2(940, 580)
		root.add_child(board)
		await get_tree().process_frame
		await get_tree().process_frame
		check(board._tabs.current_tab == 1, language + ": active investigations open on the notebook tab")
		check(board.get_combined_minimum_size().x <= 940, language + ": notebook fits the application width")
		board._tabs.current_tab = 0
		await get_tree().process_frame
		check(board._tabs.get_child(0).get_combined_minimum_size().x <= 940, language + ": original work board and objectives still fit")
		board._tabs.current_tab = 1
		var case_panel = board._tabs.get_child(1).get_child(0).get_child(0)
		var buttons := _buttons(case_panel)
		var source_clicked := false
		for b in buttons:
			if not b.disabled and ("DevIDE" in b.text):
				b.pressed.emit()
				source_clicked = true
				break
		check(source_clicked and spy.opened == [["ide", "src/auth/login.ts"]], language + ": source shortcut navigates without executing commands")
		if "--screenshots" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var output := OS.get_environment("CODIEN_QA_OUTPUT")
			var image := root.get_texture().get_image()
			check(image.save_png(output.path_join("investigation_" + language + ".png")) == OK, language + ": preview exported")
		board.queue_free()
		spy.queue_free()
		await get_tree().process_frame
	# The archive and legacy settings render without missing keys.
	Cases.close_case("d4_08")
	var dashboard := Dashboard.new()
	dashboard.theme = UITheme.build()
	dashboard.size = Vector2(940, 580)
	root.add_child(dashboard)
	await get_tree().process_frame
	check(dashboard.get_child_count() > 0, "Dashboard renders archived cases")
	dashboard.queue_free()
	Story.active = null
	await get_tree().process_frame
	# Allow the audio mixer to release any result cue from the final assertions.
	Sfx.stop_all()
	await get_tree().create_timer(0.1, true, false, true).timeout
	print("GAMEPLAY_QA: %d checks, %d failures" % [_checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result
