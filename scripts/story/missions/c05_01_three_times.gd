extends "res://scripts/story/mission.gd"
## C05 M01 — "three times" is a number, not a load scenario. Look at last year's per-minute traffic
## on campaign.nexora.test, then pick a reproducible scenario and the real bottleneck in Docs.


func _init() -> void:
	id = "c05_01"
	chapter = 5
	day = 14
	issue = "NXR-061"
	title = t("세 배라는 숫자", "Three times, they said")
	objectives = [
		{"id": "looked", "text": t("Relay에서 campaign.nexora.test 열어 작년 분당 트래픽 보기", "Open campaign.nexora.test in Relay and read last year's traffic per minute")},
		{"id": "scenario", "app": "docs", "text": t("Docs에서 부하 시나리오와 병목 고르기", "Pick the load scenario and the bottleneck in Docs")},
	]
	hints = [
		t("평균은 한 시간 내내 조용했어요. 위험한 건 20:00 첫 1분이에요. 막대 하나가 다른 막대보다 훨씬 커요.", "The average was calm all hour. The danger is the first minute at 20:00: one bar is far taller than the rest."),
		t("첫 1분에 모두가 마지막 몇 개를 동시에 눌러요. 그 순간 무엇이 겹치는지 생각해 보세요.", "In that first minute everyone presses buy on the last few items at once. What collides at that moment?"),
	]
	forms_def = {"load": {
		"title": t("캠페인 부하 시나리오", "Campaign load scenario"),
		"intro": t("영업 예상은 '작년의 세 배'예요. 리허설에 넣을 시나리오와, 그 시나리오에서 가장 먼저 깨질 곳을 골라요.",
			"Sales expects 'three times last year'. Pick the scenario for the rehearsal and what breaks first under it."),
		"submit": t("Hana에게 보내기", "Send to Hana"),
		"slots": [
			{"id": "scenario", "label": t("시나리오", "Scenario"), "options": [
				{"id": "avg3", "text": t("작년 평균의 3배를 한 시간 내내 고르게", "3x last year's average, evenly for the whole hour")},
				{"id": "peak", "text": t("작년 분당 기록 그대로 ×3 (20:00 첫 1분이 평균의 9배)", "Last year's per-minute record x3 (the first minute at 20:00 is 9x the average)")},
				{"id": "max10", "text": t("가장 큰 숫자 ×10을 모든 구간에", "The biggest number x10 on every interval")}]},
			{"id": "bottleneck", "label": t("먼저 깨질 곳", "Breaks first"), "options": [
				{"id": "inventory", "text": t("재고 예약 — 마지막 몇 개를 동시에 누름", "Inventory holds — everyone presses buy on the last few items")},
				{"id": "images", "text": t("상품 이미지 전송", "Product image delivery")},
				{"id": "db_avg", "text": t("DB CPU 평균 사용률", "Average database CPU")}]},
		],
	}}


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue(issue, title, "investigation", Game.L("나", "me"), "progress")
	say("system", t("열 번째 달 · 월요일", "Month ten · Monday"), {"channel": "general", "silent": true})
	say("alex", t("봄 한정 캠페인이 수요일 20시에 열려요. 영업은 작년의 세 배를 예상한대요. 준비 담당이 우리 팀이에요.",
		"The spring limited campaign opens Wednesday at 20:00. Sales expects three times last year. Our team owns the prep."))
	say("hana", t("SRE팀 Hana예요. 2년 만에 NEXORA로 돌아와서 이번 행사 운영을 같이 봐요. '세 배'는 숫자지 시나리오가 아니에요. campaign.nexora.test에 작년 분당 기록이 있어요.",
		"Hana from SRE. I'm back at NEXORA after two years, and I'm on this campaign's operations. 'Three times' is a number, not a scenario. Last year's per-minute record is on campaign.nexora.test."))


func open_forms() -> Array:
	if not is_done("looked"):
		return []
	return super.open_forms()


func submit_form(form_id: String, picks: Dictionary) -> Array:
	if not is_done("looked"):
		return [t("먼저 작년 기록을 보고 와요.", "Look at last year's record first.")]
	return super.submit_form(form_id, picks)


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "site" and String(d.get("site", "")) == "campaign" and not is_done("looked"):
		complete("looked")
		say("hana", t("보이죠? 한 시간 평균은 11건인데 20:00 첫 1분만 100건이에요. 그 1분을 재현해야 해요. Docs에 시나리오를 적어 주세요.",
			"See it? The hourly average is 11, but the first minute at 20:00 alone is 100. That's the minute to reproduce. Write the scenario in Docs."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes: Array = []
	match FormRules.picked(picks, "scenario")[0]:
		"avg3":
			notes.append(t("Hana: 평균의 3배면 한 시간 내내 33건이에요. 서버는 편하게 버티고, 20:00 첫 1분의 300건은 한 번도 안 만나요.",
				"Hana: 3x the average is 33 a minute all hour. The servers coast, and we never meet the 300 in the first minute."))
		"max10":
			notes.append(t("Hana: 모든 구간에 10배를 넣으면 서버를 사는 계획이 돼요. 무엇이 진짜 먼저 깨지는지는 오히려 안 보여요.",
				"Hana: 10x on every interval turns into a plan to buy servers. It hides what actually breaks first."))
	if FormRules.picked(picks, "bottleneck")[0] != "inventory":
		notes.append(t("Daniel: 작년 장애 기록을 보면 이미지나 평균 CPU는 멀쩡했어요. 첫 1분에 마지막 재고를 동시에 잡을 때 숫자가 음수가 됐죠.",
			"Daniel: Last year's incident log shows images and average CPU were fine. Stock went negative when everyone grabbed the last items in the first minute."))
	return notes


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	Game.state["flags"]["c05_scenario"] = "peak"
	complete("scenario")
	Game.advance(40)
	if once("_reward"):
		Game.relate("alex", {"work": 2})
	say("hana", t("좋아요. 리허설은 작년 분당 기록 ×3으로 돌려요. 그러면 준비 순서가 정해지네요: 재고 예약, 가격, 결제 웹훅.",
		"Good. The rehearsal replays last year's per-minute record x3. That sets the prep order: inventory holds, prices, payment webhooks."))
	doc_comment("load", "hana", t("SRE 확인: 20:00 첫 1분 300건/분 재현. 평균 부하와 순간 집중을 분리해 리허설합니다.",
		"SRE: reproduce 300/min in the first minute at 20:00. Average load and the burst are rehearsed separately."))
	finish()
