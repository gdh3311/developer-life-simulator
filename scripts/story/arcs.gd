extends RefCounted
## Storyline engine: owns the arc instances, fires their beats on the clock, limits how many
## arcs are active at once (focus slots), and resolves evening conflicts between arcs.

const MAX_ACTIVE := 2
const SCRIPTS := [
	preload("res://scripts/story/arcs/offer.gd"),
	preload("res://scripts/story/arcs/legacy17.gd"),
]
const LUNCH := 12 * 60 + 30

var _arcs: Array = []


func _init() -> void:
	for script in SCRIPTS:
		_arcs.append(script.new())


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func all() -> Array:
	return _arcs


func arc(arc_id: String) -> RefCounted:
	for a in _arcs:
		if a.id == arc_id:
			return a
	return null


func active_count() -> int:
	return _arcs.filter(func(a) -> bool: return a.is_active()).size()


## Start following an arc. Returns false when every focus slot is taken (the arc is deferred).
func accept(arc_id: String) -> bool:
	var a = arc(arc_id)
	if a == null or a.is_active():
		return a != null
	if active_count() >= MAX_ACTIVE:
		a.st()["status"] = "deferred"
		Game.notify("dashboard", Game.L("스토리라인 보류", "Storyline on hold"), Game.L("동시에 따라갈 수 있는 이야기는 %d개까지예요." % MAX_ACTIVE, "You can follow at most %d storylines at once." % MAX_ACTIVE))
		return false
	a.st()["status"] = "active"
	if a.stage() < 1:
		a.set_stage(1)
	Game.emit_event("arc_status", {"arc": arc_id, "status": "active"})
	Game.save_soon()
	return true


func defer(arc_id: String) -> void:
	var a = arc(arc_id)
	if a != null and not a.is_active():
		a.st()["status"] = "deferred"
		Game.emit_event("arc_status", {"arc": arc_id, "status": "deferred"})


func drop(arc_id: String) -> void:
	var a = arc(arc_id)
	if a != null:
		a.st()["status"] = "dropped"
		Game.emit_event("arc_status", {"arc": arc_id, "status": "dropped"})


# --- Beats ---------------------------------------------------------------------------

func _fired(a) -> Dictionary:
	if not a.data().has("fired"):
		a.data()["fired"] = {}
	return a.data()["fired"]


func _due(a, beat: Array) -> Array:
	var moved: Dictionary = a.data().get("moved", {})
	if moved.has(beat[0]):
		return moved[beat[0]]
	return [beat[1], beat[2]]


func _ready_beats(ignore_time: bool) -> Array:
	var result: Array = []
	for a in _arcs:
		for beat in a.beats:
			if _fired(a).has(beat[0]):
				continue
			var due := _due(a, beat)
			if Game.day() != int(due[0]) or (not ignore_time and Game.minutes() < int(due[1])):
				continue
			if not a.can_fire(beat[0]):
				continue
			result.append([a, beat])
	return result


func check(ignore_time := false) -> void:
	var ready := _ready_beats(ignore_time)
	var evenings := ready.filter(func(r: Array) -> bool: return r[1].size() > 3 and r[1][3] and not _moved(r[0], r[1][0]))
	if evenings.size() > 1:
		_ask_evening(evenings)
		ready = ready.filter(func(r: Array) -> bool: return not evenings.has(r))
	for r in ready:
		_fire(r[0], r[1][0])


func flush_day() -> void:
	check(true)


func _moved(a, beat_id: String) -> bool:
	return a.data().get("moved", {}).has(beat_id)


func _fire(a, beat_id: String) -> void:
	_fired(a)[beat_id] = Game.day()
	if _moved(a, beat_id):
		Game.change_condition(-5)
	Game.save_soon()
	a.fire(beat_id)


## Two arcs want the same evening: the player picks one; the other moves to tomorrow's lunch.
func _ask_evening(evenings: Array) -> void:
	var key := "arc_evening_%d" % Game.day()
	if Game.state["flags"].has(key) or Game.pending_choice(key):
		return
	var options: Array = []
	for r in evenings:
		options.append({"id": r[0].id + "|" + r[1][0], "label": r[0].evening_label(r[1][0])})
	Game.say("system", t("오늘 저녁 시간은 한 가지에만 쓸 수 있어요. 다른 하나는 내일 점심으로 미뤄집니다.",
		"Tonight you only have time for one thing. The other moves to tomorrow's lunch break."),
		{"channel": "general", "key": key, "choices": options})


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "choice" and String(d.get("key", "")).begins_with("arc_evening_"):
		var key := String(d["key"])
		if Game.state["flags"].has(key):
			return
		Game.state["flags"][key] = d["option"]
		var chosen := String(d["option"]).split("|")
		for a in _arcs:
			for beat in a.beats:
				if beat.size() > 3 and beat[3] and not _fired(a).has(beat[0]) and int(_due(a, beat)[0]) == Game.day() and a.can_fire(beat[0]):
					if a.id == chosen[0] and beat[0] == chosen[1]:
						_fire(a, beat[0])
					else:
						var moved: Dictionary = a.data().get("moved", {})
						moved[beat[0]] = [Game.day() + 1, LUNCH]
						a.data()["moved"] = moved
		Game.save_soon()
		return
	for a in _arcs:
		a.on_event(kind, d)


# --- Forms ------------------------------------------------------------------------------

func resume() -> void:
	for a in _arcs:
		a.resume()


func open_forms() -> Array:
	var result: Array = []
	for a in _arcs:
		result.append_array(a.open_forms())
	return result
