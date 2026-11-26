extends Node
## Side-ticket board + new event cards: real Git/Node/CI on ticket/<id> branches, hidden CI catching a
## partial fix, rewards and the scorecard, daily limit, hand-back, and chain integrity of every card.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Board := preload("res://scripts/apps/ticket_board.gd")
const Tickets := preload("res://scripts/story/tickets.gd")
const Cards := preload("res://scripts/story/event_cards.gd")
var _checks := 0
var _failures := 0
var _terminal: Control
var _ide: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("TK_CHECK: ", message, " = ", ok)
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


func command(line: String) -> void:
	await _terminal._execute(_terminal.tokenize(line))


func edit(path: String, content: String) -> void:
	_ide.open_file(path)
	_ide._code.text = content
	_ide.save()
	await get_tree().create_timer(0.1, true, false, true).timeout


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Engine.time_scale = 8.0
	get_tree().root.size = Vector2i(1000, 700)
	get_tree().root.content_scale_size = Vector2i(1000, 700)
	Game.reset_state()
	Game.lang = "ko"
	_cards()
	Game.state["day"] = 5
	Game.state["player_name"] = "Ticket Tester"
	for mission in Story.chapter_missions(1):
		Game.state["story"][mission.id] = {"status": "done", "obj": {}, "data": {}}
	check((await Workspace.prepare()).get("ok", false), "mounted isolated real Git workspace")
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	_terminal.visible = false
	_ide.visible = false
	await command('git config user.name "Ticket Tester"')
	await command("git config user.email tickets@example.invalid")
	await _tickets()
	await finish()


## Every new card is well formed: chains point at chain-only cards that exist, speakers exist.
func _cards() -> void:
	var all: Dictionary = Cards.ALL
	check(all.size() >= 29, "the deck has the new volume cards (%d)" % all.size())
	var broken: Array = []
	for id in all:
		var c: Dictionary = all[id]
		if not Game.NPCS.has(String(c.get("from", ""))):
			broken.append(id + ":from")
		for ch in c.get("choices", []):
			if ch.has("chain"):
				var target := String(ch["chain"][0])
				if not all.has(target) or not all[target].get("chain_only", false):
					broken.append(id + "→" + target)
			for npc in ch.get("rel", {}):
				if not npc in ["alex", "daniel", "mina", "sophie"]:
					broken.append(id + ":rel " + npc)
	check(broken.is_empty(), "card chains and speakers are valid " + str(broken))
	for id in ["sophie_review", "friday_deploy", "flaky_test", "phishing_mail", "meetup_talk", "os_update"]:
		check(all[id]["choices"].any(func(ch: Dictionary) -> bool: return ch.has("chain")), id + " has a choice that comes back later")


func _tickets() -> void:
	var b = Story.tickets
	check(b.board().size() == 4 and Game.chapter() == 2, "month two opens four tickets")
	check(b.can_take("t02") == "locked", "a chapter-three ticket stays locked")
	var view := Board.new()
	view.theme = UITheme.build()
	view.position = Vector2(20, 20)
	view.size = Vector2(760, 640)
	add_child(view)
	await get_tree().process_frame
	await capture("ticket_board_open")
	# T11 — fixed properly.
	var money: int = Game.money()
	check(await b.take("t11"), "taking a ticket pushes its module to main")
	check(b.active() == "t11" and b.can_take("t01") == "busy", "one ticket at a time")
	await command("git switch main")
	await command("git pull")
	check(FileAccess.file_exists(Workspace.resolve("src/tickets/stock_badge.ts")), "the ticket module arrives via pull")
	await command("git switch -c ticket/t11")
	await command("npm test")
	await edit("src/tickets/stock_badge.ts", Workspace.content("tickets/t11_fixed.ts"))
	await command("npm test")
	await command("git add .")
	await command('git commit -m "fix: sold-out badge at zero"')
	await command("git push")
	var opened := await CodeHub.open_pr("ticket/t11", "fix: sold-out badge", "Zero and negative stock show sold out; boundary 4/5 covered.")
	var pr: Dictionary = opened.get("pr", {})
	check(String(pr.get("mission", "")) == "ticket:t11" and pr.get("reviewer", "") == "mina", "the ticket PR belongs to the board and Mina reviews it")
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "the ticket PR merges after CI and review"):
		return
	check(int(pr["ci"].get("hidden", 0)) == 1, "CI ran the ticket's hidden check file")
	await wait_until(func() -> bool: return b.is_done("t11"), "the ticket is recorded as done")
	var rec: Dictionary = b.st()["done"].get("t11", {})
	print("TK_REC: ", JSON.stringify(rec), " money ", Game.money() - money)
	check(Game.money() - money >= 12000 and int(rec.get("ci_runs", 0)) == 1, "reward paid and one CI run recorded")
	var pct: int = b.percentile("t11", int(rec.get("minutes", 0)))
	check(pct >= 0 and pct <= 100 and b.team_times("t11").size() == 20, "the scorecard compares with twenty team times")
	check(Game.state["chat"].any(func(c: Dictionary) -> bool: return c["from"] == "mina" and Game.tx(c["text"]).contains("CI 1번")), "Mina thanks you with the scorecard")
	# T05 — a partial fix: CI's hidden checks catch it, then it's fixed.
	check(await b.take("t05"), "a second ticket the same day")
	await command("git switch main")
	await command("git pull")
	await command("git switch -c ticket/t05")
	var partial := "export function csvRow(values: string[]): string {\n  return values.map(v => (v.includes(',') ? '\"' + v + '\"' : v)).join(',');\n}\n"
	await edit("src/tickets/csv_row.ts", partial)
	await command("npm test")
	await command("git add .")
	await command('git commit -m "fix: quote commas"')
	await command("git push")
	opened = await CodeHub.open_pr("ticket/t05", "fix: CSV commas", "Quotes values with commas.")
	pr = opened.get("pr", {})
	if not await wait_until(func() -> bool: return pr["ci"]["state"] == "fail", "hidden CI catches quotes and newlines"):
		return
	check(pr["timeline"].any(func(e: Dictionary) -> bool: return e["from"] == "sophie" and Game.tx(e["text"]).contains("[CI]")), "the requester points at the [CI] checks")
	await edit("src/tickets/csv_row.ts", Workspace.content("tickets/t05_fixed.ts"))
	await command("git add .")
	await command('git commit -m "fix: escape quotes and newlines"')
	await command("git push")
	if not await wait_until(func() -> bool: return pr["state"] == "merged", "the corrected ticket merges"):
		return
	await wait_until(func() -> bool: return b.is_done("t05"), "the second ticket is done")
	check(int(b.st()["done"]["t05"].get("ci_runs", 0)) == 2, "two CI runs are on its scorecard")
	check(b.can_take("t01") == "daily", "two tickets a day is the limit")
	await get_tree().process_frame
	await capture("ticket_board_scorecards")
	# Next day: take and hand back.
	Game.state["day_done"] = true
	Game.next_day()
	check(Game.day() == 6, "the next day opens")
	check(await b.take("t01") and b.active() == "t01", "a new day allows another ticket")
	b.drop()
	check(b.active() == "" and not b.is_done("t01") and "t01" in b.board(), "a handed-back ticket returns to the board")
	check(b.progress()["done"] == 2, "progress counts finished tickets")
	view.queue_free()


func finish() -> void:
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("TICKETS_QA: %d checks, %d failures" % [_checks, _failures])
	await get_tree().create_timer(0.1, true, false, true).timeout
	# A late chat sound can start during the wait; its playback would show up as a leak at exit.
	Sfx.stop_all()
	for player in Sfx._players + [Sfx._featured] + Sfx._score_players.values():
		player.stream = null
	# The audio thread drops stopped playbacks on its own schedule; give it real time.
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
