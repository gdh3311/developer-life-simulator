extends "res://scripts/story/mission.gd"
## C04 M06 — one customer first. A simple seller starts fast; a complex one surfaces risk early.


func _init() -> void:
	id = "c04_06"
	chapter = 4
	day = 13
	issue = "NXR-056"
	title = t("고객 한 곳만 먼저", "One customer first")
	objectives = [
		{"id": "pilot", "app": "docs", "text": t("Docs에서 시범 판매자와 비교 기준 정하기", "Choose the pilot seller and comparison bar in Docs")},
		{"id": "result", "text": t("비교 기록 결과 확인", "Check the comparison results")},
	]
	forms_def = {"pilot": {
		"title": t("ATLAS 시범 판매자", "ATLAS pilot seller"),
		"intro": t("이중 기록을 한 판매자에게 먼저 켜고 일주일 치 비교 기록을 봐요.", "Turn dual write on for one seller and review a week of comparison records."),
		"submit": t("시범 시작", "Start the pilot"),
		"slots": [
			{"id": "seller", "label": t("판매자", "Seller"), "options": [
				{"id": "moonlight", "text": t("달빛상점 — 계약 단순, 환불 적음, 우리와 친함", "Moonlight — simple contract, few refunds, close to us")},
				{"id": "mosaic", "text": t("모자이크 마켓 — 첫 계약 판매자 포함, 부분 환불·재결제 많음", "Mosaic Market — includes launch-contract sellers, many partial refunds and re-payments")}]},
			{"id": "bar", "label": t("비교 기준", "Comparison bar"), "options": [
				{"id": "zero", "text": t("설명할 수 없는 차이 0건, 재처리 목록은 매일 비움", "Zero unexplained differences; the retry list is emptied daily")},
				{"id": "loose", "text": t("차이가 1% 미만이면 통과", "Pass if differences are under 1%")}]},
		],
	}}


func manual() -> bool:
	return String(Game.state["flags"].get("c04_scope", "phased")) == "status_quo"


func open_forms() -> Array:
	if manual():
		forms_def["pilot"]["title"] = t("수동 대조 시범 판매자", "Manual reconciliation pilot seller")
		forms_def["pilot"]["intro"] = t("현상 유지를 택했으니 이중 기록 대신, 한 판매자의 환불을 매주 손으로 대조하는 절차를 시범해요.",
			"Since we're keeping the current system, pilot a weekly manual refund reconciliation for one seller instead of dual write.")
		forms_def["pilot"]["submit"] = t("수동 대조 시작", "Start manual reconciliation")
	return super.open_forms()


func begin() -> void:
	Game.set_time(11 * 60)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	if manual():
		say("alex", t("현상 유지로 정했으니, 대신 손으로 대조하는 절차를 한 곳에서 먼저 해 봐요. 어디로 할까요?", "Since we're keeping things as they are, let's try a manual reconciliation routine with one seller first. Which one?"))
	else:
		say("alex", t("시범은 어디로 할까요? 달빛상점은 바로 하자고 하고, 모자이크는 예외가 많아서 걱정이래요.", "Where do we pilot? Moonlight wants to go now; Mosaic worries about its many exceptions."))


## A reload between submitting and the results must not leave the task waiting forever.
func resume() -> void:
	if form_done("pilot") and not is_done("result"):
		_show_result(String(Game.state["flags"].get("c04_pilot", "moonlight")))
		return
	super.resume()


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	if FormRules.picked(picks, "bar")[0] == "loose":
		return [t("Taeseok: 1%면 하루 수백 건이에요. 비율이 아니라 '설명할 수 없는 차이'를 세요.", "Taeseok: 1% is hundreds of records a day. Count unexplained differences, not a ratio.")]
	return []


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var seller: String = FormRules.picked(picks, "seller")[0]
	Game.state["flags"]["c04_pilot"] = seller
	complete("pilot")
	Game.advance(30)
	monitor("payments", "ok", "normal")
	await wait(1.5)
	if is_current():
		_show_result(seller)


func _show_result(seller: String) -> void:
	if is_done("result"):
		return
	if manual():
		if seller == "moonlight":
			say("mina", t("수동 대조 한 주: 2시간, 차이 0건. 할 만해요. 다만 달빛상점은 재결제가 거의 없어요.", "One week of manual reconciliation: 2 hours, zero differences. Doable. But Moonlight has almost no re-payments."))
		else:
			say("mina", t("수동 대조 한 주: 6시간, 재결제 주문 차이 3건을 손으로 찾았어요. 매주 이 시간이 들어요. 3월 재검토 때 이 숫자를 꼭 보여 줘요.",
				"One week of manual reconciliation: 6 hours, and I found 3 re-payment differences by hand. That's every week. Show this number at the March review."))
			Game.state["flags"]["c04_pilot_findings"] = 3
		Game.state["flags"]["c04_manual_hours"] = 2 if seller == "moonlight" else 6
		doc_comment("pilot", "mina", t("수동 대조 기록: 주당 %d시간." % (2 if seller == "moonlight" else 6), "Manual reconciliation log: %d hours a week." % (2 if seller == "moonlight" else 6)))
		complete("result")
		finish()
		return
	if seller == "moonlight":
		say("mina", t("일주일 치 비교: 차이 0건. 빠르게 확인됐어요. 다만 달빛상점엔 재결제가 거의 없어서, 어려운 경우는 아직 안 본 셈이에요.",
			"A week of comparison: zero differences. Quick confirmation. But Moonlight has almost no re-payments, so the hard cases are still untested."))
	else:
		var known: bool = Story.arcs.arc("legacy17") != null and Story.arcs.arc("legacy17").stage() >= 4
		say("mina", t("일주일 치 비교: 차이 3건. 셋 다 부분 환불 뒤 재결제한 주문이에요.", "A week of comparison: 3 differences, all orders re-paid after a partial refund."))
		if known:
			say("taeseok", t("LEGACY-17 이관 규칙 초안이랑 같은 패턴이에요. 결제 이력 테이블로 연결하면 셋 다 맞아요. 초안을 미리 써 둔 덕분이네요.",
				"Same pattern as the LEGACY-17 migration rule draft. Linking through the payment history table matches all three. Good thing the draft was ready."))
			Game.relate("daniel", {"tech": 3})
		else:
			say("daniel", t("예전 결제 번호 문제랑 비슷해 보여요. 어려운 경우를 일찍 찾은 거예요. 전환 전에 꼭 풀어야 할 목록이 생겼네요.",
				"Looks like the old payment-ID issue. You found the hard case early. Now there's a list we must solve before any cutover."))
		Game.state["flags"]["c04_pilot_findings"] = 3
		doc_comment("pilot", "mina", t("모자이크 시범 일주일: 재결제 주문 차이 3건 (ORD-4410, ORD-4417, ORD-4452). 전환 전 해결 목록에 올렸어요.",
			"Mosaic pilot week: 3 re-payment differences (ORD-4410, ORD-4417, ORD-4452). Added to the pre-cutover list."))
	if seller == "moonlight":
		doc_comment("pilot", "mina", t("달빛상점 시범 일주일: 차이 0건. 재결제 사례가 없어 어려운 경우는 미검증.", "Moonlight pilot week: zero differences. No re-payments, so the hard cases are untested."))
	complete("result")
	finish()
