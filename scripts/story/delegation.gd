extends RefCounted
## Delegation (roadmap 3.3): "Who takes this check?" A mission opens a request made of work pieces;
## the Docs app shows it as a form where each piece goes to a teammate (or stays with me).
## Assigned teammates report back after game time passes. Whether they succeed is never random:
##   trust    — their trust score for the piece's kind (tech or work) must reach the size's bar,
##   reach    — some people can take only pieces up to a size their evidence allows
##              (Jiwoo: mentoring_evidence takeover → small, explained → medium, independent → any),
##   needs    — the piece can need an evidence grade or a flag (e.g. a runbook line that exists),
##   load     — a person takes at most LOAD_CAP hours of open pieces at once,
##   away     — the request can mark people as unavailable.
## Every failing condition shows as a warning under that person on the form before submitting.
## A failed report names where it stopped; the piece reopens so it can be fixed and reassigned.
##
## Request spec (stored in the save, so it is plain data):
##   { id, mission, title, intro, people: [npc ids], away: [npc ids], self: bool,
##     pieces: [{ id, text, kind: "tech"|"work", size: 1..3, hours, minutes (report delay),
##                needs: [{evidence, grade} | {flag, text}], report_ok, report_fail }] }
## State: Game.state["delegation"] = { requests: {id: {spec, status, round, jobs: {piece: job}}} }
##   job = { who, status: "assigned"|"ok"|"failed"|"self", due, reasons: [{kind, text}] }
## Events: "delegation_assigned" {request, round, pieces: {piece: who}},
##         "delegation_reported" {request, piece, who, ok, reason},
##         "delegation_done" {request, results: {piece: who}}.

const SELF := "me"
const LOAD_CAP := 4
## Trust needed for each piece size.
const BAR := {1: 25, 2: 45, 3: 65}
const SIZE_NAME := {1: {"ko": "작은 일", "en": "small"}, 2: {"ko": "중간 일", "en": "medium"}, 3: {"ko": "큰 일", "en": "large"}}
## People whose reach depends on an evidence grade: the largest size they can take per grade.
const REACH := {
	"jiwoo": {"evidence": "mentoring_evidence", "sizes": {"": 1, "takeover": 1, "explained": 2, "independent": 3}},
}
const RELS := {"ok": {"work": 3}, "failed": {"work": -1}}


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	if not Game.state.has("delegation") or typeof(Game.state["delegation"]) != TYPE_DICTIONARY:
		Game.state["delegation"] = {"requests": {}}
	return Game.state["delegation"]


func request(id: String) -> Dictionary:
	return st()["requests"].get(id, {})


func status(id: String) -> String:
	return String(request(id).get("status", ""))


static func now() -> int:
	return Game.day() * 1440 + Game.minutes()


## Opens a request (no-op if it already exists, so missions can call it from begin and resume).
func open(spec: Dictionary) -> void:
	var reqs: Dictionary = st()["requests"]
	if reqs.has(spec["id"]):
		return
	reqs[spec["id"]] = {"spec": spec.duplicate(true), "status": "open", "round": 0, "jobs": {}}
	Game.notify("docs", Game.L("맡길 일", "Work to hand off"), Game.tx(spec["title"]))
	Game.emit_event("delegation_opened", {"request": spec["id"]})
	Game.save_soon()


func piece(req_id: String, piece_id: String) -> Dictionary:
	for p in request(req_id).get("spec", {}).get("pieces", []):
		if p["id"] == piece_id:
			return p
	return {}


func job(req_id: String, piece_id: String) -> Dictionary:
	return request(req_id).get("jobs", {}).get(piece_id, {})


## Pieces still waiting for an owner: never assigned, or reported as failed.
func open_pieces(req_id: String) -> Array:
	var r := request(req_id)
	return (r.get("spec", {}).get("pieces", []) as Array).filter(func(p: Dictionary) -> bool:
		return String(job(req_id, p["id"]).get("status", "")) in ["", "failed"])


func _rel(who: String, kind: String) -> int:
	return int(Game.state["rel"].get(who, {}).get(kind, 0))


## Hours of assigned, unreported pieces this person holds across every request.
func load_of(who: String) -> int:
	var total := 0
	for rid in st()["requests"]:
		for pid in st()["requests"][rid]["jobs"]:
			var j: Dictionary = st()["requests"][rid]["jobs"][pid]
			if j["who"] == who and j["status"] == "assigned":
				total += int(piece(rid, pid).get("hours", 1))
	return total


func reach_of(who: String) -> int:
	if not REACH.has(who):
		return 3
	var info: Dictionary = REACH[who]
	return int(info["sizes"].get(Story.evidence.grade(info["evidence"]), 1))


## Every reason this person would fail this piece right now; empty means they will succeed.
## extra_hours: hours already picked for them elsewhere on the same form.
func reasons(req_id: String, p: Dictionary, who: String, extra_hours := 0) -> Array:
	var out: Array = []
	if who == SELF:
		return out
	var spec: Dictionary = request(req_id).get("spec", {})
	var name := Game.npc_name(who)
	if who in spec.get("away", []):
		out.append({"kind": "away", "text": t("%s 님은 그 시간에 자리에 없어요." % name, "%s is away then." % name)})
	var size := clampi(int(p.get("size", 1)), 1, 3)
	var kind: String = p.get("kind", "tech")
	var have := _rel(who, kind)
	if have < int(BAR[size]):
		out.append({"kind": "trust", "text": t("%s 기준 %d가 필요해요 (지금 %d). %s에는 아직 이릅니다." % [Game.tx(Game.REL_KEYS[kind]), BAR[size], have, SIZE_NAME[size]["ko"]],
			"Needs %s %d (now %d). Too early for a %s piece." % [Game.tx(Game.REL_KEYS[kind]), BAR[size], have, SIZE_NAME[size]["en"]])})
	if size > reach_of(who):
		var ev: String = REACH[who]["evidence"]
		var g: String = Story.evidence.grade(ev)
		var now_text := Game.tx(Story.evidence.label(ev)) if g != "" else Game.L("기록 없음", "no record")
		out.append({"kind": "reach", "text": t("%s 기록이 '%s'라서 %s까지만 맡길 수 있어요." % [Game.tx(Story.evidence.KEYS[ev]["name"]), now_text, SIZE_NAME[reach_of(who)]["ko"]],
			"%s is '%s', so only %s pieces for now." % [Game.tx(Story.evidence.KEYS[ev]["name"]), now_text, SIZE_NAME[reach_of(who)]["en"]])})
	for need in p.get("needs", []):
		if need.has("evidence") and not Story.evidence.at_least(need["evidence"], need["grade"]):
			var key: String = need["evidence"]
			var want := Game.tx(Story.evidence.KEYS[key]["labels"][need["grade"]])
			out.append({"kind": "needs", "text": t("근거가 부족해요: %s '%s' 이상이 필요합니다." % [Game.tx(Story.evidence.KEYS[key]["name"]), want],
				"Missing evidence: needs %s at '%s' or better." % [Game.tx(Story.evidence.KEYS[key]["name"]), want])})
		elif need.has("flag") and not Game.state["flags"].get(need["flag"], false):
			out.append({"kind": "needs", "text": need.get("text", t("필요한 자료가 아직 없어요.", "Something it needs is missing."))})
	var hours := int(p.get("hours", 1))
	var held := load_of(who) + extra_hours
	if held + hours > LOAD_CAP:
		out.append({"kind": "load", "text": t("%s 님은 이미 %d시간어치를 맡고 있어요 (최대 %d)." % [name, held, LOAD_CAP],
			"%s already holds %d hours of work (max %d)." % [name, held, LOAD_CAP])})
	return out


## --- Docs form -------------------------------------------------------------------------
## Each open piece is one slot; its options are the people, each carrying its warnings.

func open_forms() -> Array:
	var out: Array = []
	for rid in st()["requests"]:
		var r: Dictionary = st()["requests"][rid]
		if r["status"] == "done":
			continue
		out.append(form_spec(rid))
	return out


func form_spec(req_id: String, picks := {}) -> Dictionary:
	var r := request(req_id)
	var spec: Dictionary = r["spec"]
	var slots: Array = []
	var shown: Array = open_pieces(req_id) if r["status"] == "open" else spec["pieces"]
	var planned := {}   # who -> hours picked on this form so far (for the load warning)
	for p in shown:
		var options: Array = []
		var people: Array = spec.get("people", []).duplicate()
		if spec.get("self", true):
			people.append(SELF)
		for who in people:
			var o := {"id": who, "text": t("내가 직접", "I'll do it") if who == SELF else {"ko": "%s · %s" % [Game.npc_name(who), Game.npc_role(who)], "en": "%s · %s" % [Game.npc_name(who), Game.npc_role(who)]}}
			var warn: Array = reasons(req_id, p, who, int(planned.get(who, 0)))
			var prev: Dictionary = job(req_id, p["id"])
			if prev.get("status", "") == "failed" and prev["who"] == who:
				warn.push_front({"kind": "again", "text": t("지난번에 여기서 멈췄어요.", "Stopped here last time.")})
			o["warn"] = warn.map(func(x: Dictionary) -> Dictionary: return x["text"])
			if who != SELF and warn.is_empty():
				o["ok"] = t("맡길 수 있어요", "Can take it")
			options.append(o)
		var size := clampi(int(p.get("size", 1)), 1, 3)
		var label := {"ko": "%s  ·  %s · %d시간" % [p["text"]["ko"], SIZE_NAME[size]["ko"], int(p.get("hours", 1))],
			"en": "%s  ·  %s · %d h" % [p["text"]["en"], SIZE_NAME[size]["en"], int(p.get("hours", 1))]}
		slots.append({"id": p["id"], "label": label, "options": options})
		var chosen := String(picks.get(p["id"], ""))
		if chosen != "" and chosen != SELF:
			planned[chosen] = int(planned.get(chosen, 0)) + int(p.get("hours", 1))
	var form := {"id": req_id, "owner": "delegation", "title": spec["title"], "intro": spec.get("intro", {}),
		"submit": t("맡기기", "Hand off"), "slots": slots, "done": r["status"] != "open", "picks": {}, "live": true}
	if r["status"] != "open":
		var picks_done := {}
		var lines: Array = []
		for p in spec["pieces"]:
			var j := job(req_id, p["id"])
			picks_done[p["id"]] = j.get("who", "")
			lines.append(_status_line(p, j))
		form["picks"] = picks_done
		form["status_lines"] = lines
	return form


func _status_line(p: Dictionary, j: Dictionary) -> Dictionary:
	var who := String(j.get("who", ""))
	var name := Game.npc_name(who)
	match String(j.get("status", "")):
		"self":
			return {"ko": "%s — 내가 맡음" % p["text"]["ko"], "en": "%s — mine" % p["text"]["en"]}
		"ok":
			return {"ko": "%s — %s 님 완료" % [p["text"]["ko"], name], "en": "%s — done by %s" % [p["text"]["en"], name]}
		"failed":
			return {"ko": "%s — %s 님이 멈춤" % [p["text"]["ko"], name], "en": "%s — %s got stuck" % [p["text"]["en"], name]}
	var left := maxi(0, int(j.get("due", 0)) - now())
	return {"ko": "%s — %s 님 진행 중 (약 %d분 뒤 보고)" % [p["text"]["ko"], name, left], "en": "%s — %s working (report in ~%d min)" % [p["text"]["en"], name, left]}


## Docs calls this. Empty result means accepted. Warnings do not block: handing a piece to someone
## who will get stuck is allowed (and is how the player learns what the warnings mean).
func submit_form(req_id: String, picks: Dictionary) -> Array:
	var r := request(req_id)
	if r.is_empty() or r["status"] != "open":
		return []
	var notes: Array = []
	var pending := open_pieces(req_id)
	for p in pending:
		if String(picks.get(p["id"], "")) == "":
			notes.append(t("'%s'을 누가 할지 정해 주세요." % p["text"]["ko"], "Choose who takes '%s'." % p["text"]["en"]))
	if not notes.is_empty():
		return notes
	r["round"] = int(r["round"]) + 1
	var planned := {}
	var assigned := {}
	for p in pending:
		var who := String(picks[p["id"]])
		var why: Array = reasons(req_id, p, who, int(planned.get(who, 0)))
		var j := {"who": who, "status": "self" if who == SELF else "assigned", "round": r["round"],
			"due": now() + int(p.get("minutes", 60)), "reasons": why}
		r["jobs"][p["id"]] = j
		assigned[p["id"]] = who
		if who != SELF:
			planned[who] = int(planned.get(who, 0)) + int(p.get("hours", 1))
	r["status"] = "waiting"
	Game.emit_event("delegation_assigned", {"request": req_id, "round": r["round"], "pieces": assigned})
	Game.emit_event("form_submitted", {"form": req_id, "owner": "delegation"})
	_after_change(req_id)
	Game.save_soon()
	return []


## --- Reports ------------------------------------------------------------------------------

## Called whenever the clock moves. Delivers due reports in due order.
func check() -> void:
	var due: Array = []
	for rid in st()["requests"]:
		var r: Dictionary = st()["requests"][rid]
		for pid in r["jobs"]:
			var j: Dictionary = r["jobs"][pid]
			if j["status"] == "assigned" and int(j["due"]) <= now():
				due.append([int(j["due"]), rid, pid])
	due.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for d in due:
		_report(d[1], d[2])


func _report(req_id: String, piece_id: String) -> void:
	var j := job(req_id, piece_id)
	var p := piece(req_id, piece_id)
	var who: String = j["who"]
	var why: Array = j.get("reasons", [])
	var ok := why.is_empty()
	j["status"] = "ok" if ok else "failed"
	Game.relate(who, RELS["ok" if ok else "failed"])
	var text: Dictionary
	if ok:
		text = p.get("report_ok", t("'%s' 확인 끝났어요. 결과는 문제없습니다." % p["text"]["ko"], "Done with '%s'. Everything checks out." % p["text"]["en"]))
	else:
		var first: Dictionary = why[0]
		var custom: Dictionary = p.get("report_fail", {}).get(first["kind"], {})
		var stopped: Dictionary = custom if not custom.is_empty() else _fail_text(first["kind"], p)
		text = {"ko": stopped["ko"] + "\n(멈춘 이유: " + first["text"]["ko"] + ")", "en": stopped["en"] + "\n(Why it stopped: " + first["text"]["en"] + ")"}
	Game.say(who, text)
	Game.emit_event("delegation_reported", {"request": req_id, "piece": piece_id, "who": who, "ok": ok, "reason": "" if ok else String(why[0]["kind"])})
	_after_change(req_id)
	Game.save_soon()


func _fail_text(kind: String, p: Dictionary) -> Dictionary:
	var what: Dictionary = p["text"]
	match kind:
		"away":
			return t("'%s'는 못 봤어요. 그 시간에 자리에 없었어요." % what["ko"], "Couldn't get to '%s'. I wasn't around." % what["en"])
		"load":
			return t("'%s'까지는 손이 안 갔어요. 맡은 일이 너무 많았어요." % what["ko"], "Didn't get to '%s'. I had too much on my plate." % what["en"])
		"needs":
			return t("'%s' 하다가 멈췄어요. 필요한 게 없어서 더 진행할 수 없었어요." % what["ko"], "Got stuck on '%s'. Something it needs was missing." % what["en"])
	return t("'%s'는 혼자 끝내기 어려웠어요. 중간에 멈췄습니다." % what["ko"], "'%s' was too much to finish alone. I stopped partway." % what["en"])


## A round ends once every piece has a result. Failed pieces reopen the form; otherwise done.
func _after_change(req_id: String) -> void:
	var r := request(req_id)
	for pid in r["jobs"]:
		if r["jobs"][pid]["status"] == "assigned":
			return
	if not open_pieces(req_id).is_empty():
		r["status"] = "open"
		Game.notify("docs", Game.L("다시 맡길 일", "Hand off again"), Game.tx(r["spec"]["title"]))
		Game.emit_event("delegation_reopened", {"request": req_id})
		return
	r["status"] = "done"
	var results := {}
	for pid in r["jobs"]:
		results[pid] = r["jobs"][pid]["who"]
	Game.emit_event("delegation_done", {"request": req_id, "results": results})


## Helpers for missions.
func results(req_id: String) -> Dictionary:
	var out := {}
	for pid in request(req_id).get("jobs", {}):
		out[pid] = job(req_id, pid)
	return out


func delegated_ok(req_id: String) -> Array:
	return results(req_id).keys().filter(func(pid: String) -> bool: return job(req_id, pid)["status"] == "ok")


func resume() -> void:
	check()
