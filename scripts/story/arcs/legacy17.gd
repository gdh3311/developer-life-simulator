extends "res://scripts/story/arc.gd"
## Storyline E — "The original owner of an old number": LEGACY-17 with Taeseok (security/audit).
## Chapter 3: take the audit sample, find the mismatch pattern, reach the person who knew why.

## [order, order.payment_ref, payment.id, events]
const ROWS := [
	["ORD-2201", "PAY-77101", "PAY-77101", {"ko": "결제", "en": "paid"}],
	["ORD-2204", "PAY-77140", "PAY-77188", {"ko": "결제 → 부분 환불 → 재결제", "en": "paid → partial refund → paid again"}],
	["ORD-2207", "P-5521", "P-5521", {"ko": "결제", "en": "paid"}],
	["ORD-2210", "PAY-77203", "PAY-77203", {"ko": "결제 → 전액 환불", "en": "paid → full refund"}],
	["ORD-2213", "P-5560", "PAY-77251", {"ko": "결제 → 부분 환불 → 재결제", "en": "paid → partial refund → paid again"}],
	["ORD-2216", "PAY-77290", "PAY-77290", {"ko": "결제", "en": "paid"}],
	["ORD-2219", "PAY-77302", "PAY-77347", {"ko": "결제 → 부분 환불 → 재결제", "en": "paid → partial refund → paid again"}],
	["ORD-2222", "P-5589", "P-5589", {"ko": "결제 → 부분 환불", "en": "paid → partial refund"}],
]
const MISMATCH := ["ORD-2204", "ORD-2213", "ORD-2219"]


func _init() -> void:
	id = "legacy17"
	npc = "taeseok"
	title = t("오래된 번호의 원래 주인 · LEGACY-17", "The original owner of an old number · LEGACY-17")
	stages = [t("제안 전", "Not offered yet"), t("감사 로그 표본 확인 예정", "Audit sample to review"),
		t("불일치 패턴 확인", "Mismatch pattern found"), t("당시 결정 메모 확보 (챕터 4)", "Original decision note found (Chapter 4)")]
	beats = [
		["offer", 8, 10 * 60 + 40, false],
		["offer2", 9, 10 * 60 + 40, false],
		["audit", 9, 18 * 60 + 20, true],
		["former", 10, 18 * 60 + 30, false],
	]
	var options: Array = []
	for r in ROWS:
		options.append({"id": r[0], "text": {"ko": "%s · 주문 쪽 %s / 결제 쪽 %s · %s" % [r[0], r[1], r[2], r[3]["ko"]],
			"en": "%s · order side %s / payment side %s · %s" % [r[0], r[1], r[2], r[3]["en"]]}})
	forms_def = {
		"audit": {
			"title": t("LEGACY-17 감사 로그 표본", "LEGACY-17 audit log sample"),
			"intro": t("예전 주문 8건의 주문 쪽 결제 번호와 결제 쪽 번호예요. 금액은 모두 맞아요. 번호가 다른 주문을 모두 고르고, 왜 달라졌는지 가장 근거 있는 설명을 고르세요.",
				"Eight old orders: the payment reference on the order and the ID on the payment side. All amounts match. Pick every order whose IDs differ, then the best-supported explanation."),
			"submit": t("Taeseok에게 보내기", "Send to Taeseok"),
			"slots": [
				{"id": "rows", "label": t("번호가 다른 주문", "Orders with mismatched IDs"), "multi": true, "options": options},
				{"id": "why", "label": t("가장 근거 있는 설명", "Best-supported explanation"), "options": [
					{"id": "format", "text": t("2023년 이관 때 번호 형식(P- → PAY-)이 바뀌어서", "The ID format changed (P- → PAY-) in the 2023 migration")},
					{"id": "repay", "text": t("부분 환불 뒤 재결제하면 결제 번호만 새로 발급되고 주문은 옛 번호를 유지해서", "After a partial refund and re-payment, only the payment side gets a new ID; the order keeps the old one")},
					{"id": "manual", "text": t("누군가 결제 번호를 수동으로 고쳐서", "Someone edited payment IDs by hand")}]},
			],
		},
	}


func evening_label(_beat: String) -> Dictionary:
	return t("LEGACY-17 감사 로그 보기 (Taeseok)", "Review the LEGACY-17 audit log (Taeseok)")


func can_fire(beat: String) -> bool:
	match beat:
		"offer":
			return status() == "locked"
		"offer2":
			return status() == "deferred"
		"audit":
			return is_active() and stage() == 1
		"former":
			return is_active() and stage() == 2
	return false


func form_open(form_id: String) -> bool:
	return form_id == "audit" and is_active() and stage() == 1 and data().get("fired", {}).has("audit")


func fire(beat: String) -> void:
	match beat:
		"offer", "offer2":
			choice("taeseok", t("보안팀 Taeseok이에요. Daniel이 LEGACY-17 이야기 했죠? 감사 로그 표본을 뽑아 둘 수 있는데, 같이 볼래요? 급한 일은 아니라서 업무 끝나고 봐도 돼요.",
				"Taeseok from Security. Daniel mentioned LEGACY-17, right? I can pull an audit log sample. Want to look at it together? Not urgent; after hours is fine."),
				"arc_l17_offer", [
					["take", t("네, 보내 주세요. 저녁에 볼게요.", "Yes, send it. I'll look this evening.")],
					["later", t("이번 주는 출시라서, 내일 다시 이야기해요.", "Launch week. Let's talk tomorrow.")],
					["pass", t("지금은 여유가 없어요. 다른 분이 보는 게 좋겠어요.", "I don't have room right now. Someone else should take it.")]])
		"audit":
			say("taeseok", t("표본 보냈어요. Docs의 'LEGACY-17 감사 로그 표본'에 있어요. 개인정보는 다 지웠어요.",
				"Sample sent. It's in Docs under 'LEGACY-17 audit log sample'. Personal data is removed."))
		"former":
			choice("taeseok", t("당시 결제 연동을 만든 분이 Hana Yoon인데, 2년 전에 퇴사했어요. 왜 그렇게 설계했는지 아는 사람은 그분뿐이에요. 어떻게 연락해 볼까요?",
				"The person who built the payment integration back then was Hana Yoon. She left two years ago, and she's the only one who knows why it was designed that way. How should we reach her?"),
				"arc_l17_contact", [
					["polite", t("Connectly로 제가 직접, 무엇을 왜 묻는지 적어서 연락할게요.", "I'll message her on Connectly myself, saying what I'm asking and why.")],
					["official", t("보안팀 공식 경로로 요청해 주세요.", "Please request it through Security's official channel.")],
					["skip", t("퇴사한 분께 연락하는 건 부담스러워요. 기록만 더 볼게요.", "Contacting someone who left feels like too much. I'll dig through records instead.")]])


func judge_form(form_id: String, picks: Dictionary) -> Array:
	if form_id != "audit":
		return []
	var notes: Array = []
	var rows: Array = FormRules.picked(picks, "rows")
	for r in rows:
		if not r in MISMATCH:
			notes.append({"ko": "%s는 두 번호가 같아요." % r, "en": "%s has matching IDs." % r})
	for m in MISMATCH:
		if not m in rows:
			notes.append(t("번호가 다른 주문이 하나 더 있어요. 두 번호 열을 한 줄씩 비교해 보세요.", "There's another mismatched order. Compare the two ID columns line by line."))
			break
	match String(FormRules.picked(picks, "why")[0] if not FormRules.picked(picks, "why").is_empty() else ""):
		"format":
			notes.append(t("ORD-2207은 옛 형식(P-)인데도 번호가 같아요. 형식만으로는 설명이 안 돼요.", "ORD-2207 uses the old format (P-) and still matches. Format alone doesn't explain it."))
		"manual":
			notes.append(t("수정 기록은 없어요. 대신 이벤트 열을 보세요. 불일치한 주문에만 있는 게 있어요.", "There's no edit record. Look at the events column; something appears only on the mismatched orders."))
	return notes


func on_form_accepted(form_id: String, _picks: Dictionary) -> void:
	if form_id != "audit":
		return
	Game.state["flags"]["l17_pattern"] = true
	set_stage(2)
	say("taeseok", t("맞아요. 부분 환불 뒤 재결제한 주문만 결제 쪽 번호가 새로 생겼어요. 금액은 맞지만, 이관할 때 주문 번호로 결제를 찾으면 세 건 다 못 찾아요. Wiki LEGACY-17에 적어 둘게요.",
		"Right. Only orders re-paid after a partial refund got a new payment-side ID. Amounts match, but if the migration looks payments up by the order's reference, all three go missing. I'll note it on the LEGACY-17 Wiki page."))


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	match String(d.get("key", "")):
		"arc_l17_offer":
			match d["option"]:
				"take":
					if Story.arcs.accept(id):
						say("taeseok", t("좋아요. 저녁에 표본 보낼게요.", "Great. I'll send the sample this evening."))
				"later":
					Story.arcs.defer(id)
					say("taeseok", t("그래요. 내일 다시 물어볼게요.", "Sure. I'll ask again tomorrow."))
				"pass":
					Story.arcs.drop(id)
					say("taeseok", t("괜찮아요. 제가 천천히 볼게요. 결과는 공유할게요.", "No problem. I'll look at it slowly and share what I find."))
		"arc_l17_contact":
			data()["contact"] = d["option"]
			match d["option"]:
				"polite":
					_hana_reply(t("안녕하세요, Hana예요. 무엇을 왜 묻는지 적어 주셔서 답하기 쉬웠어요. 그때는 결제사가 부분 환불 후 재결제에 새 번호만 줬고, 주문 테이블을 바꿀 시간이 없어서 결제 쪽 이력 테이블로 이어 붙였어요. 메모를 공유할게요. 이관 때 이력 테이블을 꼭 같이 옮기세요.",
						"Hi, this is Hana. You said what you were asking and why, which made it easy to answer. Back then the payment provider issued a new ID for re-payments after partial refunds, and we had no time to change the orders table, so we linked them through the payment history table. I'll share my note. Please migrate the history table too."), 4.0)
				"official":
					say("taeseok", t("공식 경로로 요청했어요. 시간은 좀 걸릴 거예요.", "Requested through the official channel. It'll take a bit."))
					_hana_reply(t("보안팀 요청 받았어요. 당시 결제사가 재결제에 새 번호를 줬고, 결제 이력 테이블로 연결했어요. 설계 메모를 보안팀을 통해 전달할게요.",
						"I got Security's request. The provider issued new IDs on re-payment, and we linked them via the payment history table. I'll pass the design note through Security."), 8.0)
				"skip":
					say("taeseok", t("알겠어요. 기록만으로도 꽤 갈 수 있어요. 필요해지면 그때 연락해 봐요.", "Okay. Records alone can take us a long way. We can reach out later if needed."))


func _hana_reply(text: Dictionary, delay: float) -> void:
	await wait(delay)
	if not is_active() or stage() >= 3:
		return
	Game.say("hana", text, {"channel": "connectly"})
	Game.state["flags"]["l17_note"] = true
	set_stage(3)


func summary() -> String:
	if status() == "dropped":
		return Game.L("LEGACY-17은 Taeseok이 이어서 본다", "Taeseok carries LEGACY-17 on")
	if status() in ["locked", "deferred"] and stage() == 0:
		return Game.L("LEGACY-17 표본은 아직 열어 보지 않았다", "The LEGACY-17 sample is still unopened")
	return super.summary()
