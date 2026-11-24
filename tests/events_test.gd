extends Node
## Event cards: deterministic planning, eligibility, every format (chat/call/desk visit/popup),
## chains across days, cooldowns, crisis spacing, and pending cards surviving a reload.

const MainScene := preload("res://scenes/main.tscn")
var _checks := 0
var _failures := 0
var _main: Control


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	print("EVENTS_CHECK: ", message, " = ", ok)
	if not ok:
		_failures += 1
		push_error(message)


func pause(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("CODIEN_QA_OUTPUT").path_join(name + ".png")) == OK, "exported " + name)


func ev() -> RefCounted:
	return Story.events


func ui() -> Control:
	return _main._desktop.event_ui


func goto_day(d: int, minutes := 9 * 60) -> void:
	Game.state["day"] = d
	Game.state["minutes"] = minutes
	Game.state["day_done"] = false


func queue_ids() -> Array:
	return ev().st()["queue"].map(func(q: Array) -> String: return String(q[0]))


func has_message(fragment: String) -> bool:
	return Game.state["chat"].any(func(m: Dictionary) -> bool: return fragment in Game.tx(m["text"]))


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		get_tree().quit(2)
		return
	Game.lang = "ko"
	Game.events_enabled = false
	Game.reset_state()
	Game.state["player_name"] = "Event Tester"
	Game.state["rank"] = 1
	goto_day(8)
	_main = MainScene.instantiate()
	get_tree().root.add_child.call_deferred(_main)
	var deadline := Time.get_ticks_msec() + 15000
	while (not _main.is_inside_tree() or not _main._screen_powered) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await pause(0.8)
	_main._desktop._boot.visible = false

	# Disabled engine plans nothing.
	ev().plan_day()
	check(ev().st()["queue"].is_empty() and not ev().st().has("plan_day"), "a disabled engine plans nothing")
	Game.events_enabled = true

	# Deterministic plan with the curated town hall on day 8.
	ev().plan_day()
	var first := queue_ids()
	ev().st()["plan_day"] = -1
	ev().plan_day()
	check(queue_ids() == first, "the same player and day produce the same plan")
	check("townhall" in first, "the curated town hall is planned on day 8")
	check(first.size() <= 3, "at most two random cards join the curated ones")

	# Eligibility rules.
	check(not ev().eligible("keyboard_noise"), "keyboard complaints need the RGB keyboard")
	Game.state["owned"]["keyboard_rgb"] = true
	check(ev().eligible("keyboard_noise"), "owning the keyboard makes the complaint possible")
	Game.state["owned"]["coffee_machine"] = true
	check(not ev().eligible("coffee_broken"), "your own coffee machine removes the broken-machine visit")
	Game.state["owned"].erase("coffee_machine")
	Game.state["condition"] = 60
	check(not ev().eligible("cold"), "feeling run down needs low energy")
	Game.state["condition"] = 25
	check(ev().eligible("cold"), "low energy makes the cold card possible")
	Game.state["condition"] = 85
	Game.state["rank"] = 0
	check(not ev().eligible("oncall_page"), "interns are not paged")
	Game.state["rank"] = 1
	goto_day(6)
	check(not ev().eligible("rent_notice"), "the lease notice waits for Chapter 3")
	goto_day(8)
	ev().st()["queue"] = []

	# Popup: town hall.
	var minutes_before := Game.minutes()
	var agree_before := Game.rel("alex", "agree")
	ev().fire("townhall")
	await pause(0.3)
	check(ui().card_id() == "townhall", "the popup is shown on the desktop")
	check(ui().size == _main._desktop.size and ui()._dim != null and ui()._dim.size == ui().size, "the popup dims the whole screen")
	await capture("event_popup_ko")
	ui().choose("ask")
	await pause(0.3)
	check(ui().card_id() == "" and ev().st()["pending"].is_empty(), "choosing closes the popup")
	check(Game.rel("alex", "agree") > agree_before and Game.minutes() == minutes_before + 20 and has_message("타운홀 질문"), "the town hall choice applies trust, time and a reply")

	# Call: on-call page → retro next day → coffee visit the same afternoon.
	ev().fire("oncall_page")
	await pause(0.3)
	check(ui().card_id() == "oncall_page" and ui()._ringing, "the phone rings")
	await capture("event_call_ringing_ko")
	ui().answer_call()
	await pause(0.2)
	check(not ui()._ringing and ui().card_id() == "oncall_page", "answering shows the conversation")
	ui().choose("rollback")
	check(ev().st()["chain"].any(func(c: Array) -> bool: return c[0] == "oncall_retro" and int(c[1]) == 9), "the retro is chained for the next morning")
	goto_day(9)
	ev().plan_day()
	check("oncall_retro" in queue_ids(), "the chained retro is planned for day 9")
	Game.set_time(9 * 60 + 45)
	await pause(0.2)
	var retro: Array = Game.state["chat"].filter(func(m: Dictionary) -> bool: return m["key"] == "ev_oncall_retro")
	check(retro.size() == 1, "the retro arrives as a chat message")
	if retro.size() == 1:
		Game.answer(int(retro[0]["id"]), "honest")
	check(Game.state["flags"].get("incident_notes", false) and "oncall_coffee" in queue_ids(), "an honest retro queues Alex's coffee for the afternoon")
	# Leave only the chained visit so a random card for day 9 can't take the slot first.
	if not ev().st()["pending"].is_empty():
		ui().choose(String(ev().pending()["choices"][0]["id"]))
	ev().st()["queue"] = ev().st()["queue"].filter(func(q: Array) -> bool: return q[0] == "oncall_coffee")
	Game.set_time(15 * 60 + 5)
	await pause(1.0)
	check(ui().card_id() == "oncall_coffee" and _main.visitor_npc() == "alex", "Alex stands at the desk")
	await capture("event_desk_visit_ko")
	var energy := Game.condition()
	ui().choose("thanks")
	await pause(0.8)
	check(_main.visitor_npc() == "" and Game.condition() > energy, "the visitor leaves and the coffee helps")

	# Declining a call uses its decline choice.
	energy = Game.condition()
	ev().fire("family_call")
	await pause(0.2)
	ui().choose(String(ev().card("family_call")["decline"]))
	check(Game.condition() < energy and Game.state["flags"]["event_results"]["family_call"] == "later", "declining the family call is a choice too")

	# Chat card and cooldown.
	ev().fire("lunch_vote")
	var vote: Array = Game.state["chat"].filter(func(m: Dictionary) -> bool: return m["key"] == "ev_lunch_vote")
	check(vote.size() == 1 and vote[0]["channel"] == "general", "the lunch vote is posted in #general")
	if vote.size() == 1:
		Game.answer(int(vote[0]["id"]), "join")
	check(not ev().eligible("lunch_vote"), "repeatable cards respect their cooldown")
	goto_day(11)
	check(ev().eligible("lunch_vote"), "the lunch vote can come back after the cooldown")

	# Crisis spacing over many days.
	var crisis_after_crisis := 0
	var drawn := 0
	for d in range(20, 60):
		goto_day(d)
		ev().st()["last_crisis"] = d - 1
		ev().st()["fired"].erase("oncall_page")
		ev().st()["plan_day"] = -1
		ev().plan_day()
		drawn += queue_ids().size()
		if queue_ids().any(func(id: String) -> bool: return ev().card(id).get("cat", "") == "crisis"):
			crisis_after_crisis += 1
	check(crisis_after_crisis == 0, "no crisis card the day after a crisis")
	check(drawn >= 20, "random draws still produce cards over 40 days (%d)" % drawn)
	ev().st()["queue"] = []

	# A pending card survives save and reload.
	goto_day(12)
	ev().fire("competitor_news")
	await pause(0.2)
	Game._save()
	Game.load_game()
	ui().refresh()
	await pause(0.2)
	check(ui().card_id() == "competitor_news", "a pending popup is shown again after loading")
	ui().choose("propose")
	check(Game.state["flags"].get("competitor_check", false), "the reloaded card still resolves")

	while Sfx._music.stream == null:
		await get_tree().process_frame
	Sfx.stop_all()
	print("EVENTS_QA: %d checks, %d failures" % [_checks, _failures])
	await pause(0.1)
	get_tree().quit(0 if _failures == 0 else 1)
