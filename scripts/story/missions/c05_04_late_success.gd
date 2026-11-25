extends "res://scripts/story/mission.gd"
## C05 M04 — the success that arrived late. Each webhook once, never charge twice, and route late
## successes and unknown orders to a reconciliation list a person checks instead of hiding them.


func _init() -> void:
	id = "c05_04"
	chapter = 5
	day = 15
	issue = "NXR-064"
	title = t("늦게 도착한 성공", "The success that arrived late")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 결제 웹훅 처리 받기", "Update main to get the webhook handler")},
		{"id": "hookfix", "text": t("중복·순서 바뀐 웹훅을 한 번만 반영하고 테스트 통과", "Apply duplicate and out-of-order webhooks once; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("Wiki '캠페인 준비 > 결제 웹훅'을 보세요. 처리할 수 없는 이벤트를 버리는 건 숨기는 거예요. 조정 목록으로 보내요.", "See Wiki 'Campaign prep > Payment webhooks'. Dropping an event you can't handle is hiding it. Send it to reconciliation."),
		t("가장 먼저 processed에 이벤트 id가 있는지 보고, 있으면 'duplicate'. 그 다음 주문이 없으면 'unknown_order'로 조정 목록.", "First check processed for the event id ('duplicate'). Then, if the order doesn't exist, reconciliation with 'unknown_order'."),
	]
	ai_task = {
		"label": t("결제 웹훅 중복·지연 처리", "Payment webhook duplicates and delays"),
		"files": {"src/payments/webhook.ts": "c05/webhook_ai.ts"},
		"bases": {"src/payments/webhook.ts": "c05/webhook.ts"},
		"summary": t("이벤트 id로 중복을 막고 취소된 주문의 성공은 조정 목록에 넣었습니다. 모르는 주문과 조정 목록 중복은 검증하지 않았습니다.",
			"Dedupes by event id and routes successes on cancelled orders to reconciliation. Unknown orders and duplicate reconciliation entries were not validated."),
	}


func begin() -> void:
	Game.set_time(9 * 60 + 30)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	say("system", t("열 번째 달 · 화요일", "Month ten · Tuesday"), {"channel": "general", "silent": true})
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/payments/webhook.ts": Workspace.content("c05/webhook.ts"),
			"tests/payments_webhook.test.ts": Workspace.content("c05/webhook.test.ts"),
		}, "feat(payments): webhook handler for campaign orders")
		if not is_current():
			return
		data()["_prepared"] = true
	say("hana", t("결제사는 바쁠 때 웹훅을 다시 보내요. 순서도 바뀌고요. 작년엔 고객이 취소한 뒤에 '성공'이 도착해서 취소한 주문이 결제 완료로 바뀌었어요.",
		"The gateway re-sends webhooks when it's busy, and out of order. Last year a 'success' arrived after the customer had cancelled, and the cancelled order flipped to paid."))
	say("daniel", t("처리 못 하는 이벤트를 조용히 버리면 안 돼요. 사람이 볼 수 있는 조정 목록으로 보내요. 그게 행사 다음 날 아침의 일이에요.",
		"Don't quietly drop events you can't handle. Send them to a reconciliation list a person can see. That's the morning-after work."))


func hidden_tests() -> Dictionary:
	return load_tests("c05_04")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/payments_webhook.test.ts")):
				complete("hookfix")
		"ai_used":
			data()["ai_used"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and once("_ai_note"):
				say("ai", t("CI가 모르는 주문, 이미 결제된 주문의 다른 성공, 조정 목록 중복에서 실패했어요. 설명에 적은 대로 그 경우는 검증하지 않았습니다.",
					"CI failed on unknown orders, a second success for a paid order, and duplicate reconciliation entries. As noted, I didn't validate those."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("daniel", {"tech": 3})
				await wait(1.2)
				if not is_current():
					return
				say("daniel", t("이제 늦게 온 성공은 조정 목록에 이름을 남기네요. 누가 그 목록을 볼지는 운영표에서 정해요.",
					"Late successes now leave their name on the reconciliation list. Who reads that list goes into the on-call plan."))
				finish()
