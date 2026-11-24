extends RefCounted
## Event card engine. Each workday it plans up to two cards: fixed-day (curated) cards first,
## then weighted random draws from eligible cards. Cards fire as the clock passes their minute
## and present as chat, a phone call, a teammate at the desk, or an OS popup. Choices apply
## effects (relationships, energy, money, time, flags, items) and may chain a follow-up card.
##
## state: Game.state["events"] = { plan_day, queue: [[id, minutes]], fired: {id: day},
##        chain: [[id, day, minutes]], pending: {id} , last_crisis: day }

const Cards := preload("res://scripts/story/event_cards.gd")
const MAX_PER_DAY := 2
const RANDOM_CHANCE := 0.6


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	if not Game.state.has("events") or typeof(Game.state["events"]) != TYPE_DICTIONARY:
		Game.state["events"] = {}
	var e: Dictionary = Game.state["events"]
	for key in ["queue", "chain"]:
		if not e.has(key):
			e[key] = []
	for key in ["fired", "pending"]:
		if not e.has(key):
			e[key] = {}
	return e


func card(id: String) -> Dictionary:
	return Cards.ALL.get(id, {})


func pending() -> Dictionary:
	var p: Dictionary = st()["pending"]
	return {} if p.is_empty() else card(String(p.get("id", "")))


# --- Eligibility -------------------------------------------------------------------------

func eligible(id: String) -> bool:
	var c := card(id)
	if c.is_empty():
		return false
	var e := st()
	var chapters: Array = c.get("chapters", [2, 99])
	if Game.chapter() < int(chapters[0]) or Game.chapter() > int(chapters[1]):
		return false
	if c.get("once", true) and e["fired"].has(id):
		return false
	if e["fired"].has(id) and Game.day() - int(e["fired"][id]) < int(c.get("cooldown", 99)):
		return false
	var cond: Dictionary = c.get("cond", {})
	if cond.has("rank_min") and int(Game.state["rank"]) < int(cond["rank_min"]):
		return false
	if cond.has("condition_max") and Game.condition() > int(cond["condition_max"]):
		return false
	if cond.has("owned") and not Game.state["owned"].has(cond["owned"]):
		return false
	if cond.has("not_owned") and Game.state["owned"].has(cond["not_owned"]):
		return false
	if cond.has("flag") and not Game.state["flags"].get(cond["flag"], false):
		return false
	if cond.has("not_flag") and Game.state["flags"].get(cond["not_flag"], false):
		return false
	if cond.has("arc_active") and not (Story.arcs.arc(cond["arc_active"]) != null and Story.arcs.arc(cond["arc_active"]).is_active()):
		return false
	return true


# --- Planning ----------------------------------------------------------------------------

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|day%d" % [Game.pname(), Game.day()])
	return rng


func plan_day() -> void:
	var e := st()
	if int(e.get("plan_day", -1)) == Game.day() or not Game.events_enabled:
		return
	e["plan_day"] = Game.day()
	var queue: Array = []
	var rng := _rng()
	# Chained follow-ups due today keep their minute.
	var later: Array = []
	for c in e["chain"]:
		if int(c[1]) == Game.day():
			queue.append([c[0], int(c[2])])
		elif int(c[1]) > Game.day():
			later.append(c)
	e["chain"] = later
	# Curated cards for this day.
	for id in Cards.ALL:
		var c: Dictionary = Cards.ALL[id]
		if Game.day() in c.get("days", []) and eligible(id) and queue.size() < MAX_PER_DAY + 1:
			queue.append([id, _minute(c, rng)])
	# Random draws.
	var crisis_today := queue.any(func(q: Array) -> bool: return card(q[0]).get("cat", "") == "crisis")
	var crisis_yesterday := int(e.get("last_crisis", -9)) == Game.day() - 1
	while queue.size() < MAX_PER_DAY and rng.randf() < RANDOM_CHANCE:
		var pool: Array = []
		var total := 0.0
		for id in Cards.ALL:
			var c: Dictionary = Cards.ALL[id]
			if c.has("days") or c.get("chain_only", false) or not eligible(id):
				continue
			if queue.any(func(q: Array) -> bool: return q[0] == id):
				continue
			if c.get("cat", "") == "crisis" and (crisis_today or crisis_yesterday):
				continue
			var w := float(c.get("weight", 1.0))
			if c.get("cat", "") == "life" and Game.condition() < 40:
				w *= 2.0
			pool.append([id, w])
			total += w
		if pool.is_empty():
			break
		var roll := rng.randf() * total
		for p in pool:
			roll -= p[1]
			if roll <= 0.0:
				queue.append([p[0], _minute(card(p[0]), rng)])
				if card(p[0]).get("cat", "") == "crisis":
					crisis_today = true
				break
	queue.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	e["queue"] = queue
	Game.save_soon()


func _minute(c: Dictionary, rng: RandomNumberGenerator) -> int:
	var w: Array = c.get("window", [10 * 60, 16 * 60])
	return rng.randi_range(int(w[0]), int(w[1]))


# --- Firing ------------------------------------------------------------------------------

func check(ignore_time := false) -> void:
	if not Game.events_enabled:
		return
	plan_day()
	var e := st()
	if not e["pending"].is_empty():
		return
	for q in e["queue"].duplicate():
		if ignore_time or Game.minutes() >= int(q[1]):
			e["queue"].erase(q)
			if eligible(q[0]) or card(q[0]).get("chain_only", false):
				fire(q[0])
				return


## End of day: the next card still due today gets its moment; the rest are dropped.
func flush_day() -> void:
	if not Game.events_enabled:
		return
	check(true)
	st()["queue"] = []


func fire(id: String) -> void:
	var c := card(id)
	if c.is_empty():
		return
	var e := st()
	e["fired"][id] = Game.day()
	if c.get("cat", "") == "crisis":
		e["last_crisis"] = Game.day()
	Game.save_soon()
	if c.get("format", "chat") == "chat":
		var opts := {"key": "ev_" + id, "choices": (c["choices"] as Array).map(func(ch: Dictionary) -> Dictionary: return {"id": ch["id"], "label": ch["label"]})}
		if c.has("channel"):
			opts["channel"] = c["channel"]
		Game.say(c.get("from", "system"), c["text"], opts)
	else:
		e["pending"] = {"id": id}
		Game.emit_event("event_card", {"id": id, "format": c["format"], "from": c.get("from", "")})


## Apply a choice. Called by the card UI (call/desk_visit/popup) or by a chat answer.
func resolve(id: String, choice_id: String) -> void:
	var c := card(id)
	var choice := {}
	for ch in c.get("choices", []):
		if ch["id"] == choice_id:
			choice = ch
	if c.is_empty() or choice.is_empty():
		return
	var e := st()
	if String(e["pending"].get("id", "")) == id:
		e["pending"] = {}
	var results: Dictionary = Game.state["flags"].get("event_results", {})
	if results.has(id) and c.get("once", true):
		return
	results[id] = choice_id
	Game.state["flags"]["event_results"] = results
	for npc in choice.get("rel", {}):
		Game.relate(npc, choice["rel"][npc])
	if choice.has("cond"):
		Game.change_condition(float(choice["cond"]))
	if choice.has("money"):
		var amount := int(choice["money"])
		if amount < 0:
			Game.spend(-amount)
		else:
			Game.earn(amount)
	if choice.has("mins") and not Game.state["day_done"]:
		Game.advance(int(choice["mins"]))
	if choice.has("flag"):
		Game.state["flags"][choice["flag"][0]] = choice["flag"][1]
	if choice.has("own"):
		Game.state["owned"][choice["own"]] = true
		Game.emit_event("purchase", {"id": choice["own"]})
	if choice.has("reply"):
		Game.say(choice["reply"][0], choice["reply"][1], {"silent": false} if c.get("format", "chat") != "chat" else {"channel": c.get("channel", "dm:" + String(choice["reply"][0]))})
	if choice.has("chain"):
		var ch: Array = choice["chain"]
		e["chain"].append([ch[0], Game.day() + int(ch[1]), int(ch[2])])
		if int(ch[1]) == 0:
			e["queue"].append([ch[0], int(ch[2])])
			e["queue"].sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
			e["chain"].pop_back()
	Game.emit_event("event_resolved", {"id": id, "choice": choice_id, "format": c.get("format", "chat")})
	Game.save_soon()
	check()


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "choice" and String(d.get("key", "")).begins_with("ev_"):
		resolve(String(d["key"]).substr(3), String(d["option"]))
