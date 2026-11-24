extends "res://scripts/story/mission.gd"
## C03 M01 — the launch date came first. Fit the scope into six days and write checkable criteria.

const REQUIRED := ["deadline", "cancel", "label"]
const CAPACITY := 6


func _init() -> void:
	id = "c03_01"
	chapter = 3
	day = 8
	issue = "NXR-041"
	title = t("출시일이 먼저 정해졌다", "The launch date came first")
	objectives = [
		{"id": "scope", "app": "docs", "text": t("Docs에서 예약 판매 v1 범위와 수용 조건 정하기", "Set the pre-order v1 scope and acceptance criteria in Docs")},
	]
	hints = [
		t("Wiki '예약 판매 v1 범위'에 항목별 기간이 있어요. 필수 세 가지가 5일, 가능한 기간은 6일이에요.", "The Wiki page 'Pre-order v1 scope' lists each item's cost. The three required items take five days; you have six."),
		t("수용 조건은 확인할 수 있는 문장이어야 해요. '쯤'은 확인할 수 없어요. 미룬 항목은 날짜를 약속하지 말고 기록하세요.", "Acceptance criteria must be checkable; 'around' can't be checked. Record deferred items without promising a date."),
	]
	forms_def = {
		"scope": {
			"title": t("예약 판매 v1 범위", "Pre-order v1 scope"),
			"intro": t("출시일은 정해져 있고, 개발 가능한 기간은 6일이에요. 무엇을 넣고 무엇을 미룰지 정해 Alex와 공유합니다.",
				"The launch date is fixed and there are six working days. Decide what goes in and what waits, then share it with Alex."),
			"submit": t("Alex에게 공유", "Share with Alex"),
			"slots": [
				{"id": "items", "label": t("v1에 넣을 항목", "Items in v1"), "multi": true, "capacity": CAPACITY, "options": [
					{"id": "deadline", "cost": 2, "text": t("판매자 현지 시각 마감 (필수)", "Deadline in seller local time (required)")},
					{"id": "cancel", "cost": 2, "text": t("취소와 환불 요청 분리 (필수)", "Separate cancel and refund requests (required)")},
					{"id": "label", "cost": 1, "text": t("배송 예정일 표시 (필수)", "Ship-date display (required)")},
					{"id": "limit", "cost": 2, "text": t("1인 구매 수량 제한", "Per-buyer quantity limit")},
					{"id": "coupon", "cost": 3, "text": t("쿠폰과 예약 상품 결합", "Coupons with pre-order items")},
					{"id": "sms", "cost": 2, "text": t("입고 알림 문자", "Restock SMS alerts")}]},
				{"id": "criteria", "label": t("마감 수용 조건", "Deadline acceptance criterion"), "options": [
					{"id": "exact", "text": t("판매자 현지 시각으로 정한 마감 시각 정각부터 주문할 수 없다.", "Orders are closed from the exact deadline minute in the seller's local time.")},
					{"id": "vague", "text": t("마감 시각쯤 되면 주문이 닫힌다.", "Orders close around the deadline.")},
					{"id": "server", "text": t("서버 시각 기준 자정에 주문이 닫힌다.", "Orders close at midnight server time.")}]},
				{"id": "deferred", "label": t("미룬 항목을 Alex에게 전하는 방식", "How deferred items are told to Alex")},
			],
		},
	}
	forms_def["scope"]["slots"][2]["options"] = [
		{"id": "record", "text": t("다음 버전 후보로 기록하고, 날짜는 v1 결과를 보고 정하자고 한다.", "Log them as next-version candidates and set dates after we see v1 results.")},
		{"id": "promise", "text": t("다음 주에 바로 추가해 드리겠다고 한다.", "Promise to add them next week.")},
	]


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue(issue, title, "feature", Game.L("나", "me"), "progress")
	say("system", t("네 번째 달 · 월요일", "Month four · Monday"), {"channel": "general", "silent": true})
	say("alex", t("좋은 소식이에요! 예약 판매 기능 출시일이 정해졌어요. 신규 계약 데모에 맞춰야 해서 날짜는 못 바꿔요. 판매자들이 원하는 건 많은데... 범위는 같이 정해요.",
		"Good news! The pre-order launch date is set. It has to match the new contract demo, so the date can't move. Sellers want a lot... let's set the scope together."))
	say("daniel", t("이번 기능은 처음부터 끝까지 맡아 주세요. 범위와 수용 조건부터 Docs에 적어 주면 그걸로 리뷰할게요.", "You own this feature end to end. Put the scope and acceptance criteria in Docs first; I'll review against that."))
	say("sophie", t("마감 표시 화면은 제가 맡았어요! 시간 기준은 같이 정해요.", "I've got the deadline display! Let's agree on the time basis together."), {"channel": "general"})
	say("mina", t("이번엔 실제 판매자 화면으로 테스트할 시간을 꼭 주세요.", "This time, please give me time to test on a real seller's screen."), {"channel": "general"})
	if int(Game.state["rank"]) == 0:
		say("alex", t("그리고 정규직 전환 면담은 이번 주 수요일에 다시 하기로 했어요. 이 기능이 좋은 기록이 될 거예요.", "Also, your conversion review is rescheduled for this Wednesday. This feature will be a good record."))


func judge_form(form_id: String, picks: Dictionary) -> Array:
	if form_id != "scope":
		return []
	var notes: Array = []
	var items := FormRules.picked(picks, "items")
	for r in REQUIRED:
		if not r in items:
			notes.append(t("필수 항목이 빠졌어요. 마감·취소·배송 표시는 v1의 최소 범위예요.", "A required item is missing. Deadline, cancel and ship-date display are the v1 minimum."))
			break
	var used := FormRules.cost(forms_def["scope"], "items", picks)
	if used > CAPACITY:
		notes.append(t("Alex: 6일 안에 안 들어가요. 날짜는 못 바꾸니까 하나는 다음 버전으로 미뤄야 해요. 다 넣으면 사람을 더 데려오든 품질을 깎든 해야 하는데, 둘 다 원하지 않아요.",
			"Alex: That doesn't fit in six days. The date can't move, so something has to wait. Taking it all means more people or less quality, and we want neither."))
	match FormRules.picked(picks, "criteria")[0]:
		"vague":
			notes.append(t("Mina: '쯤'은 테스트할 수 없어요. 몇 시 몇 분부터 닫히는지 적어 주세요.", "Mina: I can't test 'around'. Say exactly which minute it closes."))
		"server":
			notes.append(t("Sophie: 판매자는 자기 시간으로 마감을 정해요. 서버 시각이면 해외 판매자는 엉뚱한 시간에 닫혀요.", "Sophie: Sellers set deadlines in their own time. Server time closes overseas sellers at the wrong moment."))
	if FormRules.picked(picks, "deferred")[0] == "promise":
		notes.append(t("Daniel: 다음 주를 약속하면 v1이 끝나기도 전에 다음 일정이 생겨요. 후보로만 적어 두죠.", "Daniel: Promising next week creates a new deadline before v1 ships. Just log them as candidates."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	Game.state["flags"]["c03_scope"] = FormRules.picked(picks, "items")
	complete("scope")
	if once("_reward"):
		Game.relate("alex", {"work": 3, "agree": 2})
		Game.relate("mina", {"work": 2})
	var extra: Array = FormRules.picked(picks, "items").filter(func(x: String) -> bool: return not x in REQUIRED)
	if extra.is_empty():
		say("alex", t("좋아요. 수량 제한, 쿠폰, 알림은 다음 버전 후보로 판매자에게 그렇게 전할게요. 날짜는 v1 보고 정하고요.", "Good. I'll tell sellers the limit, coupons and alerts are next-version candidates, dates after v1."))
	else:
		say("alex", t("하나 더 넣었네요. 6일 꽉 채운 거니까, 중간에 막히면 바로 말해 줘요.", "You added one more. That's all six days, so tell me right away if you get stuck."))
	say("daniel", t("수용 조건이 테스트로 옮길 수 있는 문장이라 좋네요. 오후에 마감 처리 코드부터 봅시다.", "The criteria translate straight into tests. Let's start on the deadline code this afternoon."))
	finish()
