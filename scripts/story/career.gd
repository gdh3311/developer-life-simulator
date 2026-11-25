extends RefCounted
## Career layer: skills that grow from what you actually do, small perks they unlock, three optional
## goals per day, a grade for the day, and achievements.
##
## state: Game.state["career"] = { xp: {skill: n}, xp_today: {skill: n}, day: d,
##        goals: [{id, ...}], goals_done: [id], grades: {day: "A"}, achievements: {id: day}, counters: {} }

const SKILLS := {
	"debug": {"name": {"ko": "디버깅", "en": "Debugging"}, "color": "ff8a65"},
	"testing": {"name": {"ko": "테스트", "en": "Testing"}, "color": "3ddc84"},
	"collab": {"name": {"ko": "협업", "en": "Collaboration"}, "color": "5b8cff"},
	"ops": {"name": {"ko": "운영", "en": "Operations"}, "color": "f5a524"},
	"craft": {"name": {"ko": "제품", "en": "Product"}, "color": "c084fc"},
}
const LEVELS := [0, 40, 110, 220, 380, 600]

## Perks: [skill, level, text]. Effects are applied by Game (relate / advance / claim_salary).
const PERKS := [
	["collab", 2, {"ko": "동료 신뢰가 오를 때 +1", "en": "+1 whenever teammates' trust rises"}],
	["ops", 2, {"ko": "일할 때 컨디션 소모 20% 감소", "en": "Work drains 20% less energy"}],
	["craft", 3, {"ko": "일급 10% 보너스", "en": "+10% daily pay"}],
	["testing", 3, {"ko": "테스트 실행이 시간을 덜 씀", "en": "Test runs take less time"}],
	["debug", 3, {"ko": "AI 토큰 하루 한도 +25%", "en": "+25% daily AI tokens"}],
]

## Daily goal pool: good engineering habits, not counts. kind: needs a code task today (code),
## a review today (review) or any day (any). A red CI run is not a failure here: catching it is the point.
const GOALS := {
	"repro_first": {"skill": "debug", "kind": "code", "text": {"ko": "고치기 전에 실패를 먼저 재현하기", "en": "Reproduce the failure before fixing it"}},
	"ci_catch": {"skill": "testing", "kind": "code", "text": {"ko": "CI가 잡은 문제를 고쳐 다시 통과시키기", "en": "Fix what CI caught and get it green again"}},
	"leave_tests": {"skill": "craft", "kind": "code", "text": {"ko": "다음 사람을 위한 테스트 남기기", "en": "Leave tests behind for the next person"}},
	"explain_pr": {"skill": "collab", "kind": "code", "text": {"ko": "PR 설명에 확인한 범위 적기", "en": "Write the checked scope in your PR description"}},
	"no_main": {"skill": "craft", "kind": "code", "text": {"ko": "main에 직접 커밋하지 않기", "en": "No commits straight to main"}},
	"social": {"skill": "collab", "kind": "any", "text": {"ko": "동료에게 두 번 이상 답하기", "en": "Reply to teammates 2+ times"}},
	"no_slack": {"skill": "ops", "kind": "any", "text": {"ko": "딴짓 들키지 않기", "en": "Don't get caught slacking"}},
	"energy": {"skill": "ops", "kind": "any", "text": {"ko": "컨디션 50 이상으로 퇴근", "en": "Clock out with 50+ energy"}},
	"review": {"skill": "collab", "kind": "review", "text": {"ko": "리뷰 코멘트 남기기", "en": "Leave a review comment"}},
}
const GOAL_REWARD := 8000
const GOAL_XP := 15

## Achievements: id → {name, desc, icon}. Checked whenever something happens.
const ACHIEVEMENTS := {
	"first_commit": {"name": {"ko": "첫 커밋", "en": "First commit"}, "desc": {"ko": "작업 브랜치에 처음으로 커밋했다", "en": "Committed to a branch for the first time"}},
	"first_merge": {"name": {"ko": "첫 병합", "en": "First merge"}, "desc": {"ko": "내 PR이 main에 들어갔다", "en": "Your PR landed on main"}},
	"green5": {"name": {"ko": "초록불 다섯 번", "en": "Five greens"}, "desc": {"ko": "CI를 다섯 번 통과했다", "en": "Passed CI five times"}},
	"test_fan": {"name": {"ko": "테스트 중독", "en": "Test addict"}, "desc": {"ko": "테스트를 30번 실행했다", "en": "Ran the tests 30 times"}},
	"reviewer": {"name": {"ko": "꼼꼼한 리뷰어", "en": "Careful reviewer"}, "desc": {"ko": "리뷰 코멘트를 세 번 남겼다", "en": "Left three review comments"}},
	"detective": {"name": {"ko": "사건 수첩", "en": "Case notebook"}, "desc": {"ko": "조사 노트 세 개를 정리했다", "en": "Filed three investigations"}},
	"full_time": {"name": {"ko": "정규직", "en": "Full-timer"}, "desc": {"ko": "정규직으로 전환됐다", "en": "Became a full-time engineer"}},
	"junior2": {"name": {"ko": "한 계단 더", "en": "One step up"}, "desc": {"ko": "주니어 개발자 II가 됐다", "en": "Reached Junior Developer II"}},
	"moonlight": {"name": {"ko": "고객의 저녁", "en": "A customer's evening"}, "desc": {"ko": "달빛상점이 장부 대조를 멈췄다", "en": "Moonlight stopped cross-checking its ledger"}},
	"launch": {"name": {"ko": "내 이름이 적힌 출시", "en": "My name on a launch"}, "desc": {"ko": "예약 판매 v1을 출시했다", "en": "Shipped pre-order v1"}},
	"game_dev": {"name": {"ko": "게임 개발자", "en": "Game developer"}, "desc": {"ko": "Packet Run을 Arcade에 출시했다", "en": "Released Packet Run to the Arcade"}},
	"web_dev": {"name": {"ko": "웹 개발자", "en": "Web developer"}, "desc": {"ko": "moonlight.shop을 공개했다", "en": "Published moonlight.shop"}},
	"perfect_day": {"name": {"ko": "완벽한 하루", "en": "Perfect day"}, "desc": {"ko": "하루 평가 S를 받았다", "en": "Got an S for the day"}},
	"goal_getter": {"name": {"ko": "목표 사냥꾼", "en": "Goal getter"}, "desc": {"ko": "오늘의 목표를 10개 달성했다", "en": "Completed 10 daily goals"}},
	"specialist": {"name": {"ko": "전문 분야", "en": "Specialist"}, "desc": {"ko": "한 스킬이 4레벨에 도달했다", "en": "A skill reached level 4"}},
	"decorator": {"name": {"ko": "책상 꾸미기", "en": "Desk stylist"}, "desc": {"ko": "책상 소품을 세 번 바꿨다", "en": "Changed desk items three times"}},
	"rgb": {"name": {"ko": "빛나는 키보드", "en": "Glowing keyboard"}, "desc": {"ko": "RGB 키보드를 샀다", "en": "Bought the RGB keyboard"}},
	"caught": {"name": {"ko": "들켰다", "en": "Busted"}, "desc": {"ko": "딴짓하다 상사에게 들켰다", "en": "Caught slacking by the boss"}},
	"other_path": {"name": {"ko": "다른 길", "en": "Another path"}, "desc": {"ko": "스토리라인 하나를 챕터 끝까지 따라갔다", "en": "Followed a storyline to its chapter end"}},
	"lunch_club": {"name": {"ko": "점심 동료", "en": "Lunch club"}, "desc": {"ko": "동료들과 점심을 같이 먹었다", "en": "Had lunch with the team"}},
}


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	if not Game.state.has("career") or typeof(Game.state["career"]) != TYPE_DICTIONARY:
		Game.state["career"] = {}
	var c: Dictionary = Game.state["career"]
	for key in ["xp", "xp_today", "grades", "achievements", "counters"]:
		if not c.has(key) or typeof(c[key]) != TYPE_DICTIONARY:
			c[key] = {}
	for key in ["goals", "goals_done"]:
		if not c.has(key) or typeof(c[key]) != TYPE_ARRAY:
			c[key] = []
	return c


# --- Skills --------------------------------------------------------------------------

func xp(skill: String) -> int:
	return int(st()["xp"].get(skill, 0))


static func level_for(points: int) -> int:
	var lv := 1
	for i in LEVELS.size():
		if points >= LEVELS[i]:
			lv = i + 1
	return mini(lv, LEVELS.size())


func level(skill: String) -> int:
	return level_for(xp(skill))


## Progress inside the current level: [into, span] (span 0 at max level).
func progress(skill: String) -> Array:
	var lv := level(skill)
	if lv >= LEVELS.size():
		return [0, 0]
	return [xp(skill) - LEVELS[lv - 1], LEVELS[lv] - LEVELS[lv - 1]]


func has_perk(skill: String, lv: int) -> bool:
	return level(skill) >= lv


func gain(skill: String, amount: int) -> void:
	if not SKILLS.has(skill) or amount <= 0:
		return
	var before := level(skill)
	st()["xp"][skill] = xp(skill) + amount
	st()["xp_today"][skill] = int(st()["xp_today"].get(skill, 0)) + amount
	var after := level(skill)
	if after > before:
		var perk := ""
		for p in PERKS:
			if p[0] == skill and int(p[1]) == after:
				perk = " · " + Game.tx(p[2])
		Game.notify("dashboard", Game.L("레벨 업! %s %d", "Level up! %s %d") % [Game.tx(SKILLS[skill]["name"]), after],
			Game.L("새로 익힌 감각", "You've got a feel for it") + perk)
		Sfx.play("success", 1.2, -6.0)
		Game.emit_event("skill_up", {"skill": skill, "level": after})
	Game.save_soon()


# --- Daily goals -------------------------------------------------------------------------

func _ensure_day() -> void:
	var c := st()
	if int(c.get("day", -1)) == Game.day():
		return
	c["day"] = Game.day()
	c["xp_today"] = {}
	c["caps_today"] = {}
	c["today"] = {"test_cases": _test_case_count()}
	c["goals_done"] = []
	c["goals"] = _pick_goals()


func _today_kinds() -> Array:
	var kinds := ["any"]
	for m in Story.chapter_missions(Game.chapter()):
		if m.day != Game.day():
			continue
		if m.has_objective("pr") or m.has_objective("tests") or m.has_objective("merged"):
			kinds.append("code")
		if m.has_objective("review"):
			kinds.append("review")
	return kinds


func _pick_goals() -> Array:
	var kinds := _today_kinds()
	var pool: Array = GOALS.keys().filter(func(id: String) -> bool: return GOALS[id]["kind"] in kinds)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("goals|%s|%d" % [Game.pname(), Game.day()])
	var picked: Array = []
	# Prefer one code goal on code days so the day's main work matters.
	var code: Array = pool.filter(func(id: String) -> bool: return GOALS[id]["kind"] == "code")
	if not code.is_empty():
		picked.append(code[rng.randi_range(0, code.size() - 1)])
	while picked.size() < 3 and picked.size() < pool.size():
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not id in picked:
			picked.append(id)
	return picked


func _today_flags() -> Dictionary:
	if not st().has("today") or typeof(st()["today"]) != TYPE_DICTIONARY:
		st()["today"] = {}
	return st()["today"]


## How many test cases exist in the working copy (to tell whether tests were added today).
func _test_case_count() -> int:
	if not (Workspace.is_ready and Workspace.exists()):
		return 0
	var n := 0
	for path in Workspace.list_files():
		var p := String(path)
		if p.begins_with("tests/") and p.ends_with(".test.ts"):
			n += Workspace.read_file(p).count("test(")
	return n


func goals() -> Array:
	_ensure_day()
	return st()["goals"]


func _today(key: String) -> int:
	return int(Game.state["stats_today"].get(key, 0))


## Live status of a goal: "done", "failed" (can no longer be met today) or "open".
func goal_status(id: String) -> String:
	if id in st()["goals_done"]:
		return "done"
	var end: bool = Game.state["day_done"]
	var today := _today_flags()
	match id:
		"repro_first":
			return "done" if today.get("reproduced", false) else ("failed" if end else "open")
		"ci_catch":
			return "done" if today.get("ci_recovered", false) else ("failed" if end else "open")
		"leave_tests":
			return "done" if today.get("tests_added", false) else ("failed" if end else "open")
		"explain_pr":
			return "done" if today.get("explained", false) else ("failed" if end else "open")
		"no_main":
			if _today("main_commits") > 0:
				return "failed"
			return "done" if end and _today("commits") > 0 else ("failed" if end else "open")
		"social":
			return "done" if _today("choices") >= 2 else "open"
		"no_slack":
			if _today("caught_slacking") > 0:
				return "failed"
			return "done" if end else "open"
		"energy":
			return "done" if end and Game.condition() >= 50 else ("failed" if end else "open")
		"review":
			return "done" if _today("reviews") >= 1 else "open"
	return "open"


func _check_goals() -> void:
	for id in goals():
		if id in st()["goals_done"] or goal_status(id) != "done":
			continue
		st()["goals_done"].append(id)
		var c: Dictionary = st()["counters"]
		c["goals"] = int(c.get("goals", 0)) + 1
		Game.earn(GOAL_REWARD)
		gain(String(GOALS[id]["skill"]), GOAL_XP)
		Game.notify("tasks", Game.L("오늘의 목표 달성", "Daily goal complete"), "✓ " + Game.tx(GOALS[id]["text"]) + "  ·  +" + Game.won(GOAL_REWARD))
		Sfx.play("tick")


# --- Grade ----------------------------------------------------------------------------------

## S: all three goals and nothing caught · A: two goals · B: one · C: none.
## A red CI run doesn't lower the grade: CI catching a problem is the system working.
func grade_for_today() -> String:
	var done := goals().filter(func(id: String) -> bool: return goal_status(id) == "done").size()
	if done >= 3 and _today("caught_slacking") == 0:
		return "S"
	return ["C", "B", "A", "A"][mini(done, 3)]


func finish_day() -> void:
	_check_goals()
	var g := grade_for_today()
	st()["grades"][str(Game.day())] = g
	if g == "S":
		gain("craft", 10)
		gain("collab", 10)
	_check_achievements()
	Game.save_soon()


func grade(day: int) -> String:
	return String(st()["grades"].get(str(day), ""))


# --- Achievements -------------------------------------------------------------------------

func unlocked(id: String) -> bool:
	return st()["achievements"].has(id)


func _met(id: String) -> bool:
	var flags: Dictionary = Game.state["flags"]
	match id:
		"first_commit": return Game.stat("commits") >= 1
		"first_merge": return Game.stat("merges") >= 1
		"green5": return Game.stat("ci_pass") >= 5
		"test_fan": return Game.stat("test_runs") >= 30
		"reviewer": return Game.stat("reviews") >= 3
		"detective": return Cases.archive().size() >= 3
		"full_time": return int(Game.state["rank"]) >= 1
		"junior2": return int(Game.state["rank"]) >= 2
		"moonlight": return String(Game.state["story"].get("c02_08", {}).get("status", "")) == "done"
		"launch": return flags.get("c03_released", false)
		"game_dev": return not ArcadeStudio.release().is_empty()
		"web_dev": return not PageStudio.release().is_empty()
		"perfect_day": return st()["grades"].values().has("S")
		"goal_getter": return int(st()["counters"].get("goals", 0)) >= 10
		"specialist": return SKILLS.keys().any(func(s: String) -> bool: return level(s) >= 4)
		"decorator": return int(st()["counters"].get("desk_changes", 0)) >= 3
		"rgb": return Game.state["owned"].has("keyboard_rgb")
		"caught": return Game.stat("caught_slacking") >= 1
		"other_path": return Story.arcs.all().any(func(a) -> bool: return a.stage() >= 3)
		"lunch_club": return int(st()["counters"].get("lunch", 0)) > 0
	return false


func _check_achievements() -> void:
	for id in ACHIEVEMENTS:
		if unlocked(id) or not _met(id):
			continue
		st()["achievements"][id] = Game.day()
		Game.notify("dashboard", Game.L("🏆 업적 달성", "🏆 Achievement"), Game.tx(ACHIEVEMENTS[id]["name"]) + " — " + Game.tx(ACHIEVEMENTS[id]["desc"]))
		Sfx.play("success", 1.1, -4.0)
		Game.emit_event("achievement", {"id": id})


# --- What earns XP ------------------------------------------------------------------------
## Growth comes from distinct work, not repetition (docs/GAMEPLAY.md): repeated actions are
## capped per day, CI pays once per PR, and commits themselves earn nothing.

func _capped(key: String, limit: int) -> bool:
	if not st().has("caps_today") or typeof(st()["caps_today"]) != TYPE_DICTIONARY:
		st()["caps_today"] = {}
	var caps: Dictionary = st()["caps_today"]
	var n := int(caps.get(key, 0))
	if n >= limit:
		return true
	caps[key] = n + 1
	return false


func _once(key: String) -> bool:
	var c: Dictionary = st()["counters"]
	if c.has(key):
		return false
	c[key] = true
	return true


func on_event(kind: String, d: Dictionary) -> void:
	if kind in ["achievement", "skill_up"]:
		return
	_ensure_day()
	match kind:
		"tests":
			var today := _today_flags()
			if not d.get("ok", false):
				today["saw_failure"] = true
			elif today.get("saw_failure", false):
				today["reproduced"] = true
			if d.get("ok", false) and _test_case_count() > int(today.get("test_cases", 1 << 30)):
				today["tests_added"] = true
			if not _capped("tests", 3):
				gain("testing", 4 if d.get("ok", false) else 2)
		"ci":
			var pr_id := int(d.get("pr", 0))
			if CodeHub.get_pr(pr_id).get("author", "") == "me":
				var today := _today_flags()
				var red: Array = today.get("red_prs", [])
				if not d.get("ok", false):
					if not pr_id in red:
						red.append(pr_id)
					today["red_prs"] = red
				elif pr_id in red:
					today["ci_recovered"] = true
			if CodeHub.get_pr(pr_id).get("author", "") == "me" and d.get("ok", false) and _once("ci_pr_%d" % pr_id):
				gain("testing", 10)
		"pr_merged":
			if CodeHub.get_pr(int(d.get("pr", 0))).get("author", "") == "me":
				gain("craft", 15)
		"pr_opened":
			gain("collab", 4)
			if String(CodeHub.get_pr(int(d.get("pr", 0))).get("body", "")).strip_edges().length() >= 30:
				_today_flags()["explained"] = true
		"player_review":
			gain("collab", 8)
			gain("debug", 6)
		"choice":
			Game.inc_stat("choices")
			if not _capped("choice", 5):
				gain("collab", 2)
			if String(d.get("key", "")) in ["d1_lunch", "ev_lunch_vote"] and String(d.get("option", "")) == "join":
				st()["counters"]["lunch"] = int(st()["counters"].get("lunch", 0)) + 1
		"form_submitted":
			gain("collab", 6)
			gain("craft", 4)
		"request_experiment", "reproduction_plan", "ticket_evidence":
			gain("debug", 5)
		"rollout":
			gain("ops", 4)
		"monitor_viewed":
			if not _capped("monitor", 2):
				gain("ops", 3)
		"event_resolved":
			if String(d.get("id", "")).begins_with("oncall"):
				gain("ops", 12)
		"arcade_submitted", "page_released":
			gain("craft", 25)
		"desk_changed":
			st()["counters"]["desk_changes"] = int(st()["counters"].get("desk_changes", 0)) + 1
	_check_goals()
	_check_achievements()
