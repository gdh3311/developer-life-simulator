extends "res://scripts/story/mission.gd"
## C04 M04 — the numbers don't match on Friday. Classify each difference; don't hide it as tolerance.

## [row id, order/refund line, correct category]
const ROWS := [
	["r1", {"ko": "ORD-3101 · 주문 합계 33,333원 / 환불 합계 16,667원 · 절반 환불", "en": "ORD-3101 · order total ₩33,333 / refund ₩16,667 · half refund"}, "rounding"],
	["r2", {"ko": "ORD-3108 · 00:30 KST 환불이 UTC 기준 정산 표에서는 전날 15:30", "en": "ORD-3108 · a 00:30 KST refund is 15:30 the previous day in the UTC finance sheet"}, "period"],
	["r3", {"ko": "ORD-3112 · 주문 시스템 12,000 / 정산 1,200,000", "en": "ORD-3112 · orders say 12,000 / finance says 1,200,000"}, "unit"],
	["r4", {"ko": "ORD-3115 · 환불 기록이 원장에만 없음 · 재처리 목록에도 없음", "en": "ORD-3115 · refund missing from the ledger only · not in the retry list"}, "missing"],
	["r5", {"ko": "ORD-3119 · 첫 계약 판매자 환불 6,170원 / 계산기 6,173원", "en": "ORD-3119 · launch-contract refund ₩6,170 / calculator ₩6,173"}, "rounding"],
	["r6", {"ko": "ORD-3121 · 15:10 UTC 주문이 한국 날짜로는 다음 날 00:10", "en": "ORD-3121 · a 15:10 UTC order is 00:10 the next day in Korea"}, "period"],
]
const CATEGORIES := [
	["rounding", {"ko": "반올림 규칙", "en": "Rounding rule"}],
	["period", {"ko": "집계 기간", "en": "Period / time zone"}],
	["unit", {"ko": "단위 (원/전)", "en": "Unit (won/cents)"}],
	["missing", {"ko": "실제 누락", "en": "Actually missing"}],
	["tolerance", {"ko": "허용 오차", "en": "Tolerance"}],
]


func _init() -> void:
	id = "c04_04"
	chapter = 4
	day = 12
	issue = "NXR-054"
	title = t("숫자가 맞지 않는 금요일", "The numbers don't match on Friday")
	objectives = [{"id": "report", "app": "docs", "text": t("Docs에서 차이 6건을 원인별로 분류한 대조 보고서 제출", "Submit a reconciliation report classifying six differences in Docs")}]
	hints = [
		t("단위가 100배 차이 나면 단위, 날짜 경계 근처면 집계 기간, 첫 계약 판매자면 반올림 규칙을 의심해요.", "A 100× gap suggests units; near a date boundary, the period; launch-contract sellers, the rounding rule."),
		t("'허용 오차'로 덮으면 다음 달에도 같은 차이가 나와요. 실제 누락은 재처리 목록과 비교해 보세요.", "Calling it tolerance means the same gap next month. Compare a real omission with the retry list."),
	]
	var slots: Array = []
	for r in ROWS:
		slots.append({"id": r[0], "label": r[1], "inline": true, "options": CATEGORIES.map(func(c: Array) -> Dictionary: return {"id": c[0], "text": c[1]})})
	forms_def = {"recon": {
		"title": t("환불 대조 보고서", "Refund reconciliation report"),
		"intro": t("Taeseok이 보낸 표본 6건이에요. 각 차이가 왜 생겼는지 분류해요. 금액은 모두 실제 기록에서 왔어요.", "Six samples from Taeseok. Classify why each difference happened. Every amount comes from real records."),
		"submit": t("Taeseok에게 보내기", "Send to Taeseok"),
		"slots": slots,
	}}


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue(issue, title, "investigation", Game.L("나", "me"), "progress")
	say("taeseok", t("금요일 정산에서 주문 합계와 환불 합계가 안 맞는 표본이 나왔어요. 금액이 작다고 '오차'로 넘기기 전에 하나씩 분류해 줄래요? Docs에 올려 뒀어요.",
		"Friday's settlement has samples where order and refund totals don't match. Before anyone calls it rounding error, could you classify each one? It's in Docs."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var wrong := 0
	var hid := false
	for r in ROWS:
		var p := FormRules.picked(picks, r[0])
		if p.is_empty():
			continue
		if p[0] == "tolerance":
			hid = true
		elif p[0] != r[2]:
			wrong += 1
	var notes: Array = []
	if hid:
		notes.append(t("Taeseok: '허용 오차'로 덮으면 다음 달에도 같은 차이가 나와요. 원인을 적어 주세요.", "Taeseok: If we call it tolerance, the same gap shows up next month. Name the cause."))
	if wrong > 0:
		notes.append({"ko": "Taeseok: %d건은 원인이 다른 것 같아요. 날짜 경계, 금액 자릿수, 판매자 계약을 다시 보세요." % wrong,
			"en": "Taeseok: %d look like a different cause. Recheck date boundaries, digit counts and seller contracts." % wrong})
	return notes


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	complete("report")
	Game.advance(40)
	if once("_reward"):
		Game.relate("alex", {"work": 2})
	say("taeseok", t("깔끔하네요. 진짜 누락은 ORD-3115 한 건이고, 나머지는 규칙 차이예요. 그 한 건이 이중 기록 전에 생긴 거라 재처리 목록에 없었네요. 오늘 고친 코드였으면 남았을 거예요.",
		"Clean. The only real omission is ORD-3115; the rest are rule differences. That one happened before dual write, which is why it isn't in the retry list. With today's fix it would have been queued."))
	Game.state["flags"]["c04_recon"] = true
	doc_comment("recon", "taeseok", t("정산팀 확인: 실제 누락은 ORD-3115 한 건. 나머지 다섯 건은 규칙 차이로 분류해 다음 달부터 자동 설명을 붙일게요.",
		"Finance confirmed: ORD-3115 is the only real omission. The other five are rule differences; we'll annotate them automatically from next month."))
	finish()
