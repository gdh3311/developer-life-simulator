extends RefCounted
## Evidence record: long-term state that later chapters read (docs/SCENARIO_CHARACTERS.md, "장기 상태 설계").
## Each key holds a grade earned from what the player actually did, not from one conversation.
## Game.state["evidence"] = {
##   "keys": { key: {"grade", "source", "day", "history": [{grade, source, day}]} },
##   "applied": [rule ids already used],
## }
## Ordered keys only move up through rules (refresh); a later chapter may lower them with set_grade().
## Choice keys (career_focus, atlas_outcome) record a decision and have no order.

static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


const KEYS := {
	"idempotency_evidence": {
		"name": {"ko": "중복 요청 처리", "en": "Duplicate requests"},
		"grades": ["missing", "sequential", "concurrent"],
		"labels": {"missing": {"ko": "근거 없음", "en": "No evidence"}, "sequential": {"ko": "순차 재전송 확인", "en": "Sequential retries"}, "concurrent": {"ko": "동시 요청까지 확인", "en": "Concurrent requests"}},
		"next": {"missing": {"ko": "같은 요청이 두 번 와도 주문이 하나인지 테스트로 보여 주세요.", "en": "Show with a test that two identical requests make one order."},
			"sequential": {"ko": "동시에 들어온 두 요청도 한 번만 처리되는지 확인해 보세요.", "en": "Check that two simultaneous requests are also handled once."}},
		"uses": {"ko": "늦게 도착한 옛 주문을 자동으로 걸러 낼 수 있는 범위", "en": "How much of a late replay is filtered automatically"},
	},
	"log_contract": {
		"name": {"ko": "로그 기준", "en": "Logging rules"},
		"grades": ["unsafe", "minimal", "verified"],
		"labels": {"unsafe": {"ko": "개인정보가 남음", "en": "Personal data kept"}, "minimal": {"ko": "추적 정보만", "en": "Tracing fields only"}, "verified": {"ko": "조사에서 검증됨", "en": "Proven in an investigation"}},
		"next": {"unsafe": {"ko": "로그에 요청 ID와 결과만 남기도록 고쳐 보세요.", "en": "Keep only the request ID and result in logs."},
			"minimal": {"ko": "실제 조사에서 이 기준만으로 재현이 되는지 확인하면 올라갑니다.", "en": "Rises once a real investigation reproduces a bug with these fields alone."}},
		"uses": {"ko": "사고 조사에 쓸 수 있는 자료와 추가로 지울 것", "en": "What an investigation can use and what must be scrubbed first"},
	},
	"ledger_evidence": {
		"name": {"ko": "원장 대조", "en": "Ledger reconciliation"},
		"grades": ["untracked", "sampled", "reconciled"],
		"labels": {"untracked": {"ko": "기록 없음", "en": "Untracked"}, "sampled": {"ko": "표본 비교", "en": "Sampled"}, "reconciled": {"ko": "대조와 원복까지", "en": "Reconciled and rolled back"}},
		"next": {"untracked": {"ko": "두 저장소의 기록을 나란히 남겨 비교할 수 있게 해 보세요.", "en": "Write both stores side by side so they can be compared."},
			"sampled": {"ko": "차이를 원인별로 분류하고, 되돌려도 주문이 남는지 확인해 보세요.", "en": "Classify every difference, then check that a rollback keeps every order."}},
		"uses": {"ko": "전환 때 자동으로 끝나는 대조 범위", "en": "How much reconciliation runs by itself during the cutover"},
	},
	"handoff_quality": {
		"name": {"ko": "인계", "en": "Handoffs"},
		"grades": ["personal", "documented", "rehearsed"],
		"labels": {"personal": {"ko": "내 머릿속에만", "en": "Only in my head"}, "documented": {"ko": "문서로 남김", "en": "Written down"}, "rehearsed": {"ko": "다른 사람이 해 봄", "en": "Someone else ran it"}},
		"next": {"personal": {"ko": "담당과 운영 설명서를 문서로 남겨 보세요.", "en": "Write down the owner and a runbook."},
			"documented": {"ko": "다른 사람이 그 문서만 보고 일을 끝내면 올라갑니다.", "en": "Rises when someone else finishes a job using only your document."}},
		"uses": {"ko": "자리를 비웠을 때 다른 사람이 맡을 수 있는 범위", "en": "What others can take over while you're away"},
	},
	"shared_ownership": {
		"name": {"ko": "일의 분담", "en": "Shared ownership"},
		"grades": ["concentrated", "assigned", "verified"],
		"labels": {"concentrated": {"ko": "나에게 몰림", "en": "Concentrated on me"}, "assigned": {"ko": "담당을 나눔", "en": "Owners assigned"}, "verified": {"ko": "양쪽이 확인함", "en": "Confirmed by both sides"}},
		"next": {"concentrated": {"ko": "당직과 담당을 다른 사람과 나눠 보세요.", "en": "Split on-call and ownership with others."},
			"assigned": {"ko": "다른 팀과 담당과 보류 기준을 함께 적으면 올라갑니다.", "en": "Rises when owners and hold rules are agreed with another team."}},
		"uses": {"ko": "동시 작업을 나눌 수 있는 정도와 퇴근 뒤 호출", "en": "How work splits during crunch, and calls after hours"},
	},
	"mentoring_evidence": {
		"name": {"ko": "멘토링", "en": "Mentoring"},
		"grades": ["takeover", "explained", "independent"],
		"labels": {"takeover": {"ko": "대신 고침", "en": "Took over"}, "explained": {"ko": "설명함", "en": "Explained"}, "independent": {"ko": "혼자 해냄", "en": "Works independently"}},
		"next": {"takeover": {"ko": "다음 PR에서는 고치는 대신 이유와 확인 방법을 남겨 보세요.", "en": "Next time, leave the reason and how to check instead of fixing it."},
			"explained": {"ko": "같은 사람이 다음 PR을 혼자 끝내면 올라갑니다.", "en": "Rises when they finish the next PR on their own."}},
		"uses": {"ko": "후배에게 맡길 수 있는 확인 작업", "en": "Which checks a junior can take on"},
		"from": 7,
	},
	"automation_report": {
		"name": {"ko": "자동화 보고", "en": "Automation report"},
		"grades": ["inflated", "qualified", "measured"],
		"labels": {"inflated": {"ko": "성과만 남김", "en": "Gains only"}, "qualified": {"ko": "한계를 적음", "en": "Limits noted"}, "measured": {"ko": "검토 시간까지 측정", "en": "Review time measured"}},
		"next": {"inflated": {"ko": "보고서에 검토 시간이나 한계를 함께 적어 보세요.", "en": "Add review time or the limits to the report."},
			"qualified": {"ko": "검토·운영·재처리 시간을 실제로 재면 올라갑니다.", "en": "Rises when review, operations and rework time are measured."}},
		"uses": {"ko": "이후 인력 계획이 실제 작업량과 맞는지", "en": "Whether later staffing plans match the real workload"},
		"from": 8,
	},
	"recovery_plan": {
		"name": {"ko": "회복 계획", "en": "Recovery plan"},
		"grades": ["none", "requested", "supported"],
		"labels": {"none": {"ko": "없음", "en": "None"}, "requested": {"ko": "요청함", "en": "Requested"}, "supported": {"ko": "팀이 지원함", "en": "Supported by the team"}},
		"next": {"none": {"ko": "지칠 때 휴식이나 업무 조정을 요청해 보세요.", "en": "Ask for rest or a lighter load when you're worn out."},
			"requested": {"ko": "요청한 조정이 실제 교대표에 반영되면 올라갑니다.", "en": "Rises when the change you asked for shows up on the rota."}},
		"uses": {"ko": "긴 전환 날의 교대와 휴식 장면", "en": "Shifts and rest during the long cutover"},
		"from": 7,
	},
	"career_focus": {
		"name": {"ko": "역할", "en": "Role"},
		"choice": true,
		"grades": ["undecided", "technical", "lead"],
		"labels": {"undecided": {"ko": "아직 정하지 않음", "en": "Undecided"}, "technical": {"ko": "기술 전문", "en": "Technical"}, "lead": {"ko": "리드", "en": "Lead"}},
		"uses": {"ko": "후반 업무가 기술 검토 중심인지 조정 중심인지", "en": "Whether later work leans on technical review or coordination"},
		"from": 7,
	},
	"atlas_outcome": {
		"name": {"ko": "ATLAS 전환", "en": "ATLAS cutover"},
		"choice": true,
		"grades": ["complete", "phased", "restored"],
		"labels": {"complete": {"ko": "전환 완료", "en": "Complete"}, "phased": {"ko": "단계 적용", "en": "Phased"}, "restored": {"ko": "안전하게 복귀", "en": "Safely restored"}},
		"uses": {"ko": "서비스 후일담", "en": "The service epilogue"},
		"from": 11,
	},
}

## Display order on the Dashboard.
const ORDER := ["idempotency_evidence", "log_contract", "ledger_evidence", "handoff_quality", "shared_ownership",
	"mentoring_evidence", "automation_report", "recovery_plan", "career_focus", "atlas_outcome"]

## Where a grade came from, for the "source" line.
const SOURCES := {
	"c02_03": {"ko": "같은 요청 두 번", "en": "The same request twice"},
	"c02_04": {"ko": "남겨야 할 로그", "en": "What the log should keep"},
	"c02_06": {"ko": "버튼 바깥의 중복", "en": "Duplicates beyond the button"},
	"c03_07": {"ko": "다음 주에도 내 일", "en": "Still mine next week"},
	"c04_03": {"ko": "두 번 적는 이유", "en": "Why we write twice"},
	"c04_04": {"ko": "숫자가 맞지 않는 금요일", "en": "The Friday the numbers didn't match"},
	"c05_04": {"ko": "늦게 도착한 성공", "en": "A success that arrived late"},
	"c05_05": {"ko": "누가 밤에 받나요", "en": "Who takes the night?"},
	"c06_04": {"ko": "이 일은 우리 팀 건가요", "en": "Is this our team's ticket?"},
	"c06_05": {"ko": "되돌릴 수 있는 이관", "en": "A reversible transfer"},
	"c06_06": {"ko": "예전 동료에게 보내는 요청", "en": "A request across the table"},
	"jw_shipping": {"ko": "지우의 배송비 PR", "en": "Jiwoo's shipping fee PR"},
	"jw_boxes": {"ko": "지우의 상자 수 PR", "en": "Jiwoo's box count PR"},
}


# --- State ----------------------------------------------------------------------------

func st() -> Dictionary:
	if typeof(Game.state.get("evidence")) != TYPE_DICTIONARY:
		Game.state["evidence"] = {}
	var e: Dictionary = Game.state["evidence"]
	if typeof(e.get("keys")) != TYPE_DICTIONARY:
		e["keys"] = {}
	if typeof(e.get("applied")) != TYPE_ARRAY:
		e["applied"] = []
	return e


func entry(key: String) -> Dictionary:
	return st()["keys"].get(key, {})


## Current grade id, or "" when nothing has been recorded yet.
func grade(key: String) -> String:
	return String(entry(key).get("grade", ""))


## Position in the key's order (-1 when unrecorded or unknown).
func rank(key: String) -> int:
	if not KEYS.has(key):
		return -1
	return (KEYS[key]["grades"] as Array).find(grade(key))


func at_least(key: String, g: String) -> bool:
	var need := (KEYS.get(key, {}).get("grades", []) as Array).find(g)
	return need >= 0 and rank(key) >= need


## Record a grade (may lower it). Keeps every earlier grade in history.
func set_grade(key: String, g: String, source: String) -> bool:
	if not KEYS.has(key) or not (g in KEYS[key]["grades"]):
		return false
	var e := entry(key)
	if String(e.get("grade", "")) == g:
		return false
	var history: Array = e.get("history", [])
	history.append({"grade": g, "source": source, "day": Game.day()})
	st()["keys"][key] = {"grade": g, "source": source, "day": Game.day(), "history": history}
	Game.emit_event("evidence_changed", {"key": key, "grade": g, "source": source})
	Game.save_soon()
	return true


## Record only if it improves the grade (choice keys: only if nothing is recorded yet).
func raise(key: String, g: String, source: String) -> bool:
	if not KEYS.has(key):
		return false
	if KEYS[key].get("choice", false):
		return grade(key) == "" and set_grade(key, g, source)
	if (KEYS[key]["grades"] as Array).find(g) <= rank(key):
		return false
	return set_grade(key, g, source)


func first_grade(key: String) -> String:
	var history: Array = entry(key).get("history", [])
	return String(history[0]["grade"]) if not history.is_empty() else ""


# --- Rules from chapters 1–6 ------------------------------------------------------------

func _done(id: String) -> bool:
	return String(Game.state["story"].get(id, {}).get("status", "")) == "done"


func _flag(key: String, default = null):
	return Game.state["flags"].get(key, default)


func _split_before() -> bool:
	return (_done("c03_07") and _flag("c03_owner") == "pair") or (_done("c05_05") and int(_flag("c05_rota_self", 0)) < 2)


## [rule id, key, grade, source mission, condition]. Each rule is used once, in order.
func _rules() -> Array:
	return [
		["c02_03", "idempotency_evidence", "sequential", "c02_03", func() -> bool: return _done("c02_03")],
		["c02_06", "idempotency_evidence", "concurrent", "c02_06", func() -> bool: return _done("c02_06")],
		["c05_04", "idempotency_evidence", "sequential", "c05_04", func() -> bool: return _done("c05_04")],
		["c02_04", "log_contract", "minimal", "c02_04", func() -> bool: return _done("c02_04")],
		["c04_03", "ledger_evidence", "sampled", "c04_03", func() -> bool: return _done("c04_03")],
		["c04_04", "ledger_evidence", "sampled", "c04_04", func() -> bool: return _done("c04_04")],
		["c06_05", "ledger_evidence", "reconciled", "c06_05", func() -> bool: return _done("c06_05") and _done("c04_04")],
		["c03_07", "handoff_quality", "documented", "c03_07", func() -> bool: return _done("c03_07")],
		["c06_06", "handoff_quality", "documented", "c06_06", func() -> bool: return _done("c06_06")],
		["c03_07_pair", "shared_ownership", "assigned", "c03_07", func() -> bool: return _done("c03_07") and _flag("c03_owner") == "pair"],
		["c05_05_alone", "shared_ownership", "concentrated", "c05_05", func() -> bool: return _done("c05_05") and int(_flag("c05_rota_self", 0)) >= 2],
		["c05_05", "shared_ownership", "assigned", "c05_05", func() -> bool: return _done("c05_05") and int(_flag("c05_rota_self", 0)) < 2],
		# "Verified" needs owners split before (chapter 3 or 5) and then agreed with another team.
		["c06_04", "shared_ownership", "verified", "c06_04", func() -> bool: return _done("c06_04") and _split_before()],
		["c06_04_first", "shared_ownership", "assigned", "c06_04", func() -> bool: return _done("c06_04")],
	]


## Applies rules whose conditions now hold. Returns the keys that changed.
## The first call on a save just records what the player already earned, without notices.
func refresh() -> Array:
	var e := st()
	var quiet: bool = not e.get("seeded", false)
	var applied: Array = e["applied"]
	var changed: Array = []
	for r in _rules():
		if r[0] in applied or not (r[4] as Callable).call():
			continue
		applied.append(r[0])
		if raise(r[1], r[2], r[3]) and not (r[1] in changed):
			changed.append(r[1])
	e["seeded"] = true
	if not quiet:
		for key in changed:
			Game.notify("dashboard", Game.L("📒 내 기록", "📒 My record"), "%s → %s" % [Game.tx(KEYS[key]["name"]), Game.tx(label(key))])
	return changed


# --- Display ------------------------------------------------------------------------

func label(key: String) -> Dictionary:
	var g := grade(key)
	if g == "":
		return t("기록 없음", "Not recorded")
	return KEYS[key]["labels"][g]


func source_text(key: String) -> String:
	var s := String(entry(key).get("source", ""))
	if s == "":
		return ""
	return Game.tx(SOURCES[s]) if SOURCES.has(s) else s


## What would raise this key, or "" at the top / for choices.
func next_text(key: String) -> String:
	var info: Dictionary = KEYS[key]
	if info.get("choice", false):
		return ""
	var g := grade(key)
	if g == "":
		g = info["grades"][0]
	return Game.tx(info["next"][g]) if info.get("next", {}).has(g) else ""


## Keys the player has reached (by chapter) or already has a grade for.
func visible_keys() -> Array:
	return ORDER.filter(func(k: String) -> bool: return grade(k) != "" or Game.chapter() >= int(KEYS[k].get("from", 1)))
