extends RefCounted
## Base class for a storyline (arc): an optional story the player chooses to follow alongside
## the main missions. Beats fire on the clock; choices and Docs forms move the arc forward.
##
## state: Game.state["arcs"][id] = { status, stage, data }
## status: locked (not offered yet) · offered · active · deferred · dropped
## Beats: [beat_id, day, minutes, evening(bool)] — fired once when due and allowed by can_fire().

const FormRules := preload("res://scripts/story/form_rules.gd")

var id := ""
var title := {}
var npc := ""
var stages: Array = []          # [{ko,en}] stage names (index = stage)
var beats: Array = []
var forms_def := {}


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	var arcs: Dictionary = Game.state["arcs"]
	if not arcs.has(id):
		arcs[id] = {"status": "locked", "stage": 0, "data": {}}
	return arcs[id]


func data() -> Dictionary:
	return st()["data"]


func status() -> String:
	return String(st()["status"])


func stage() -> int:
	return int(st()["stage"])


func is_active() -> bool:
	return status() == "active"


func set_stage(n: int) -> void:
	if n <= stage():
		return
	st()["stage"] = n
	Game.notify("dashboard", Game.tx(title), Game.tx(stages[clampi(n, 0, stages.size() - 1)]))
	Game.emit_event("arc_stage", {"arc": id, "stage": n})
	Game.save_soon()


func once(key: String) -> bool:
	if data().get(key, false):
		return false
	data()[key] = true
	return true


func say(from: String, text, opts := {}) -> Dictionary:
	return Game.say(from, text, opts)


func choice(from: String, text, key: String, options: Array, opts := {}) -> Dictionary:
	var o := opts.duplicate()
	o["key"] = key
	o["choices"] = options.map(func(c: Array) -> Dictionary: return {"id": c[0], "label": c[1]})
	return Game.say(from, text, o)


func wait(sec: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(sec).timeout


# --- Overridables ---------------------------------------------------------------------

## May this beat fire now? (stage/status gates)
func can_fire(_beat: String) -> bool:
	return true


func fire(_beat: String) -> void:
	pass


func on_event(_kind: String, _d: Dictionary) -> void:
	pass


## Called after a save is loaded: re-arm anything that was waiting on a timer.
func resume() -> void:
	pass


## One line for the Dashboard / chapter ending.
func summary() -> String:
	return Game.tx(stages[clampi(stage(), 0, stages.size() - 1)])


# --- Docs forms --------------------------------------------------------------------------

func form_open(_form_id: String) -> bool:
	return false


func open_forms() -> Array:
	var result: Array = []
	for k in forms_def:
		if form_open(k) or form_done(k):
			var spec: Dictionary = forms_def[k].duplicate()
			spec["id"] = k
			spec["done"] = form_done(k)
			spec["picks"] = data().get("forms", {}).get(k, {})
			spec["arc"] = id
			result.append(spec)
	return result


func form_done(form_id: String) -> bool:
	return data().get("forms", {}).has(form_id)


func submit_form(form_id: String, picks: Dictionary) -> Array:
	if not form_open(form_id) or form_done(form_id):
		return []
	var notes := FormRules.missing(forms_def[form_id], picks)
	if notes.is_empty():
		notes = judge_form(form_id, picks)
	if not notes.is_empty():
		return notes
	var forms: Dictionary = data().get("forms", {})
	forms[form_id] = picks.duplicate(true)
	data()["forms"] = forms
	Game.save_soon()
	Game.emit_event("form_submitted", {"form": form_id, "arc": id})
	on_form_accepted(form_id, picks)
	return []


func judge_form(_form_id: String, _picks: Dictionary) -> Array:
	return []


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	pass
