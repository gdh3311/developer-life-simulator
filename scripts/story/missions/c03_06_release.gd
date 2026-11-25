extends "res://scripts/story/mission.gd"
## C03 M06 — the first release note. Rollback conditions and what to check after launch.

const GOOD_CHECKS := ["blocked", "cancel_mix", "inquiries"]


func _init() -> void:
	id = "c03_06"
	chapter = 3
	day = 10
	issue = "NXR-046"
	title = t("첫 출시 공지", "The first release note")
	objectives = [
		{"id": "release", "app": "docs", "text": t("Docs에서 출시 공지·되돌리기 조건·확인 지표 정하기", "Write the release note, rollback rule and checks in Docs")},
	]
	hints = [
		t("Wiki '출시와 담당'을 보세요. 확인 지표는 기능이 실제로 하는 일을 보여 줘야 해요.", "See the Wiki page 'Release and ownership'. Checks should show what the feature actually does."),
	]
	forms_def = {
		"release": {
			"title": t("예약 판매 출시 공지", "Pre-order release note"),
			"intro": t("판매자 전체에게 나가는 공지와, 출시 후 우리가 지켜볼 것을 정합니다.", "The note that goes to every seller, and what we watch after launch."),
			"submit": t("출시", "Launch"),
			"slots": [
				{"id": "note", "label": t("공지 문장", "Release note"), "options": [
					{"id": "plain", "text": t("판매자 현지 시각으로 예약 마감을 정할 수 있습니다. 결제 전 취소와 결제 후 환불 요청이 나뉘고, 배송 준비 중인 주문은 판매자가 확인합니다.", "You can set pre-order deadlines in your local time. Cancels before payment and refund requests after payment are separate, and you review orders already in preparation.")},
					{"id": "jargon", "text": t("deadlineUtc 오프셋 처리와 CancelResult 상태 머신을 도입했습니다.", "Introduced deadlineUtc offset handling and a CancelResult state machine.")},
					{"id": "over", "text": t("예약 판매의 모든 문제를 해결했습니다.", "Every pre-order problem is solved.")}]},
				{"id": "rollback", "label": t("되돌리는 조건", "Rollback condition"), "options": [
					{"id": "metric", "text": t("마감 이후 주문 생성 1건, 또는 환불 누락 1건이면 플래그를 끈다.", "Turn the flag off on any order after a deadline or any missing refund.")},
					{"id": "none", "text": t("되돌릴 일은 없을 것이다.", "We won't need to roll back.")}]},
				{"id": "checks", "label": t("출시 후 확인 지표", "Post-launch checks"), "multi": true, "max": 3, "options": [
					{"id": "blocked", "text": t("마감 직후 주문 차단 로그", "Order-blocking logs right after deadlines")},
					{"id": "cancel_mix", "text": t("취소 요청의 상태 분포 (취소 / 환불 요청 / 판매자 확인)", "Cancel-request state mix (cancelled / refund / seller review)")},
					{"id": "inquiries", "text": t("배송 예정 문구 관련 문의 수", "Inquiries about ship-date wording")},
					{"id": "cpu", "text": t("서버 CPU 사용률", "Server CPU usage")}]},
			],
		},
	}


func begin() -> void:
	Game.set_time(10 * 60)
	Game.add_issue(issue, title, "release", Game.L("나", "me"), "progress")
	say("system", t("네 번째 달 · 수요일 · 출시일", "Month four · Wednesday · launch day"), {"channel": "general", "silent": true})
	say("alex", t("오늘이에요! 공지 문장이랑 되돌리기 조건만 정해 주면 바로 켤게요.", "Today's the day! Give me the note and the rollback rule and I'll flip it on."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes: Array = []
	match FormRules.picked(picks, "note")[0]:
		"jargon":
			notes.append(t("Yuri: 판매자는 함수 이름을 몰라요. 판매자가 할 수 있게 된 일로 써 주세요.", "Yuri: Sellers don't know function names. Write what they can now do."))
		"over":
			notes.append(t("Daniel: 확인한 범위보다 크게 말하면 다음 문의 때 신뢰를 잃어요.", "Daniel: Claiming more than we verified costs trust at the next inquiry."))
	if FormRules.picked(picks, "rollback")[0] == "none":
		notes.append(t("Mina: 되돌릴 조건이 없으면 문제가 생겼을 때 누가 끌지 밤에 정하게 돼요.", "Mina: Without a rollback rule, someone decides at night whether to switch it off."))
	var checks := FormRules.picked(picks, "checks")
	if "cpu" in checks:
		notes.append(t("Daniel: CPU는 예약 판매와 상관없이 오르내려요. 이 기능이 하는 일을 보여 주는 숫자를 골라요.", "Daniel: CPU moves for reasons unrelated to pre-orders. Pick numbers that show what this feature does."))
	elif checks.size() < 3:
		notes.append(t("확인 지표를 세 개 골라 주세요.", "Pick three checks."))
	return notes


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	complete("release")
	Game.advance(30)
	monitor("api", "ok", "normal")
	Game.state["flags"]["c03_released"] = true
	Game.state["connectly"]["portfolio_preorder"] = true
	if once("_reward"):
		Game.relate("alex", {"work": 3})
		Game.relate("daniel", {"work": 2})
	say("alex", t("켰어요! 첫 한 시간, 지정한 세 숫자 모두 기준 안이에요.", "It's live! First hour: all three numbers are within bounds."))
	say("mina", t("마감 직후 차단 로그 깨끗해요. 판매자 확인 상태도 정상으로 쌓여요.", "Post-deadline blocking logs are clean. Seller-review states are piling up normally."), {"channel": "general"})
	Game.notify("browser", "Connectly", Game.L("포트폴리오에 '예약 판매 v1 출시'가 추가됐습니다.", "'Pre-order v1 launch' was added to your portfolio."))
	say("yuri", t("Relay에서 moonlight.shop 열어 보세요. 손님 화면에서 예약하고 취소 요청도 눌러 볼 수 있어요. 마감 시각이랑 취소 동작이 우리가 만든 그대로예요.",
		"Open moonlight.shop in Relay. You can pre-order and request cancels from the customer's side. The deadline and cancel behavior are exactly what we built."))
	finish()
