extends Node
## Career layer: XP from real events, level-ups, perk effects, daily goals, day grade,
## achievements, save/load, and the redesigned day summary + Dashboard panel.

const Desktop := preload("res://scripts/desktop/desktop.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Dashboard := preload("res://scripts/apps/dashboard_app.gd")
var _checks := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	_checks += 1
	print("CAREER_CHECK: ", label, " = ", ok)
	if not ok:
		_failures += 1
		push_error(label)


func capture(name: String) -> void:
	if "--screenshots" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "captured " + name)


func pause(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func c() -> RefCounted:
	return Story.career


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Game.reset_state()
	Game.state["player_name"] = "Career Tester"
	Game.state["day"] = 5
	Game.state["rank"] = 1
	get_tree().root.content_scale_size = Vector2i(1080, 740)
	get_tree().root.size = Vector2i(1080, 740)

	# Goals for a code day include a code goal and are deterministic.
	var picked: Array = c().goals()
	check(picked.size() == 3 and picked.any(func(id: String) -> bool: return c().GOALS[id]["kind"] == "code"), "a code day gets three goals including a code goal")
	c().st()["day"] = -1
	check(c().goals() == picked, "the same player and day get the same goals")

	# XP from real events.
	Game.emit_event("tests", {"ok": true})
	check(c().xp("testing") == 4 and int(c().st()["xp_today"]["testing"]) == 4, "passing tests grows Testing")
	for i in 5:
		Game.emit_event("tests", {"ok": true})
	check(c().xp("testing") == 12, "rerunning tests over and over doesn't farm XP (3 runs a day count)")
	Game.state["stats"]["commits"] = 40
	Game.emit_event("git_committed", {"branch": "x"})
	check(c().xp("craft") == 0, "commits alone earn no XP")
	Game.state["stats"]["commits"] = 0
	Game.emit_event("choice", {"key": "x", "option": "y"})
	check(c().xp("collab") == 2 and int(Game.state["stats_today"].get("choices", 0)) == 1, "answering a teammate grows Collaboration")
	var ups := [0]
	var watch := func(kind: String, _d: Dictionary) -> void:
		if kind == "skill_up":
			ups[0] += 1
	Game.event.connect(watch)
	c().gain("testing", 30)
	check(c().level("testing") == 2 and ups[0] == 1, "crossing a threshold levels up once")
	Game.event.disconnect(watch)

	# Perks change real numbers.
	Game.state["rel"]["mina"]["close"] = 50
	Game.relate("mina", {"close": 10})
	var plain: int = Game.rel("mina", "close") - 50
	Game.state["rel"]["mina"]["close"] = 50
	c().gain("collab", 60)
	Game.relate("mina", {"close": 10})
	check(Game.rel("mina", "close") - 50 == plain + 1, "Collaboration Lv2 adds +1 to trust gains")
	Game.state["condition"] = 80
	Game.advance(80)
	var drain_plain: int = 80 - Game.condition()
	Game.state["condition"] = 80
	c().gain("ops", 60)
	Game.advance(80)
	check(80 - Game.condition() < drain_plain, "Operations Lv2 drains less energy")
	check(Game.ai_daily_tokens() == Game.AI_DAILY_TOKENS, "AI tokens start at the normal limit")
	c().gain("debug", 120)
	check(Game.ai_daily_tokens() == roundi(Game.AI_DAILY_TOKENS * 1.25), "Debugging Lv3 raises the daily AI tokens")
	c().gain("craft", 120)
	Game.state["day_done"] = true
	var before: int = Game.money()
	Game.claim_salary()
	check(Game.money() - before == roundi(Game.SALARY[1] * 1.1), "Product Lv3 pays 10% more")
	Game.state["day_done"] = false

	# Goals: live status, reward once, failure.
	c().st()["goals"] = ["repro_first", "social", "no_slack"]
	c().st()["goals_done"] = []
	check(c().goal_status("repro_first") == "open" and c().goal_status("no_slack") == "open", "goals start open")
	var money: int = Game.money()
	Game.emit_event("tests", {"ok": true})
	check(c().goal_status("repro_first") == "open", "passing tests alone isn't reproducing a failure")
	Game.emit_event("tests", {"ok": false})
	Game.emit_event("tests", {"ok": true})
	Game.emit_event("choice", {"key": "a", "option": "b"})
	check(c().goal_status("repro_first") == "done" and c().goal_status("social") == "done", "seeing the failure, then fixing it, completes the goal")
	check(Game.money() == money + 2 * c().GOAL_REWARD, "each goal pays once")
	Game.emit_event("choice", {"key": "a", "option": "b"})
	check(Game.money() == money + 2 * c().GOAL_REWARD, "a finished goal doesn't pay twice")

	# The day summary with the grade (before the day closes the slack goal is still open).
	var desktop := Desktop.new()
	desktop.theme = UITheme.build()
	desktop.size = Vector2(1080, 740)
	add_child(desktop)
	desktop._boot.hide()
	Game.state["day_done"] = true
	c().finish_day()
	check(c().grade(5) == "S" and c().unlocked("perfect_day"), "three goals and nothing caught make an S and an achievement")
	check(not c().GOALS.has("ci_clean") and not c().GOALS.has("tests3") and not c().GOALS.has("no_hints"), "no goal rewards counting runs or never failing")
	for toast in desktop._toasts.get_children():
		toast.hide()
	desktop._show_day_summary()
	await pause(0.8)
	check(desktop._overlay != null, "the day summary opens")
	await capture("career_day_summary")
	desktop._overlay.queue_free()
	desktop._overlay = null

	# A bad day.
	Game.state["day"] = 6
	Game.state["day_done"] = false
	Game.state["stats_today"] = {}
	c().st()["day"] = -1
	c().goals()
	c().st()["goals"] = ["no_slack", "energy", "social"]
	Game.inc_stat("caught_slacking")
	Game.emit_event("caught", {})
	check(c().goal_status("no_slack") == "failed", "getting caught fails the slack goal")
	Game.state["condition"] = 20
	Game.state["day_done"] = true
	c().finish_day()
	check(c().grade(6) == "C" and c().unlocked("caught"), "a rough day is a C, and getting caught is remembered")

	# Achievements from stats.
	Game.state["stats"]["commits"] = 1
	Game.emit_event("git_committed", {"branch": "feature/x"})
	check(c().unlocked("first_commit"), "the first commit unlocks its achievement")

	# Dashboard panel.
	var dash := Dashboard.new()
	dash.theme = UITheme.build()
	var panel: Control = preload("res://scripts/apps/career_panel.gd").dashboard()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UITheme.BG0
	bg.size = Vector2(1080, 740)
	layer.add_child(bg)
	panel.theme = UITheme.build()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(1040, 0)
	layer.add_child(panel)
	await pause(0.2)
	check(panel.find_children("*", "PanelContainer", true, false).size() >= c().ACHIEVEMENTS.size(), "the trophy shelf shows every achievement")
	await capture("career_dashboard")
	layer.queue_free()
	dash.free()

	# Save and load.
	DirAccess.make_dir_recursive_absolute("user://sandbox")
	Game._save()
	var xp_before: int = c().xp("testing")
	Game.state["career"] = {}
	check(Game.load_game() and c().xp("testing") == xp_before and c().grade(5) == "S", "career progress survives save and load")

	Sfx.stop_all()
	await pause(0.12)
	print("CAREER_QA: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
