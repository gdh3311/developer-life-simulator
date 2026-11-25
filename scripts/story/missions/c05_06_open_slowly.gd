extends "res://scripts/story/mission.gd"
## C05 M06 — open to a few first. Pick the staged opening and the rate limit, answer Seojin's request
## for an extra hour, then 20:00 happens: the rush runs through the repository's real code and the
## result is saved for campaign.nexora.test. Good preparation means nothing happens. That's the point.


func _init() -> void:
	id = "c05_06"
	chapter = 5
	day = 15
	issue = "NXR-066"
	title = t("열 분만 먼저 열기", "Open to a few first")
	objectives = [
		{"id": "plan", "app": "docs", "text": t("Docs에서 단계별 개방과 요청 제한 정하기", "Choose the staged opening and rate limit in Docs")},
		{"id": "extend", "text": t("달빛상점의 연장 판매 요청에 답하기", "Answer Moonlight's request for extra hours")},
		{"id": "rush", "text": t("20:00 오픈", "Open at 20:00")},
		{"id": "watched", "text": t("campaign.nexora.test에서 행사 결과 보기", "Read the result on campaign.nexora.test")},
	]
	hints = [
		t("결제사는 분당 200건까지 받아요. 제한을 풀면 그 위는 오류 화면이에요.", "The gateway takes 200 payments a minute. Remove the limit and everything above that is an error page."),
		t("서진의 부탁은 들어줄 수도, 줄일 수도, 거절할 수도 있어요. 운영표에 그 시간 담당이 있는지 보세요.", "You can grant, shrink or decline Seojin's request. Check whether the rota covers that hour."),
	]
	forms_def = {"launch": {
		"title": t("봄 캠페인 개방 계획", "Spring campaign opening plan"),
		"intro": t("20:00 첫 1분에 약 300명이 들어와요. 재고는 120개. 결제사 한도는 분당 200건.", "About 300 people arrive in the first minute at 20:00. 120 items in stock. The gateway accepts 200 payments a minute."),
		"submit": t("Alex에게 보내기", "Send to Alex"),
		"slots": [
			{"id": "stage", "label": t("개방 방식", "Opening"), "options": [
				{"id": "ten", "text": t("사전 알림 신청 고객 10%에게 10분 먼저, 20:10 전체", "10% (notification sign-ups) get ten minutes early; everyone at 20:10")},
				{"id": "all", "text": t("20:00 전체 동시 개방", "Everyone at 20:00")},
				{"id": "no_coupon", "text": t("20:00 전체 개방, 쿠폰 중복 적용 기능은 이번에 제외", "Everyone at 20:00, coupon stacking left out this time")}]},
			{"id": "limit", "label": t("요청 제한", "Rate limit"), "options": [
				{"id": "keep", "text": t("분당 120명 입장 유지 + 대기 안내", "Keep 120 per minute, with a waiting-room notice")},
				{"id": "double", "text": t("분당 240명으로 완화", "Relax to 240 per minute")},
				{"id": "off", "text": t("제한 해제", "No limit")}]},
		],
	}}


func begin() -> void:
	Game.set_time(16 * 60)
	Game.add_issue(issue, title, "release", Game.L("나", "me"), "progress")
	say("alex", t("오늘 20시예요. 어떻게 열지 정해 줘요. 전부 한 번에 열자는 의견도, 나눠 열자는 의견도 있어요.", "It's 20:00 tonight. Decide how we open. Some want everything at once, some want it staged."))


func resume() -> void:
	if form_done("launch") and not is_done("extend") and not Game.pending_choice("c05_extend"):
		_ask_extension()
		return
	if is_done("extend") and not is_done("rush"):
		_open()
		return
	super.resume()


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	if FormRules.picked(picks, "limit")[0] == "off":
		return [t("Hana: 제한을 풀면 첫 1분 300명이 결제사 한도 200을 넘어요. 넘친 사람은 대기 안내 대신 오류 화면을 봐요.",
			"Hana: With no limit, 300 people in the first minute exceed the gateway's 200. The overflow sees an error page instead of a waiting notice.")]
	return []


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	Game.state["flags"]["c05_launch"] = {"stage": FormRules.picked(picks, "stage")[0], "limit": FormRules.picked(picks, "limit")[0]}
	complete("plan")
	Game.advance(30)
	await wait(1.0)
	if is_current():
		_ask_extension()


func _ask_extension() -> void:
	if Game.pending_choice("c05_extend"):
		return
	say("yuri", t("달빛상점 서진 사장님이 직접 연락하셨어요. 행사 마지막 날 한 시간만 더 열 수 있냐고요.", "Seojin from Moonlight reached out directly. Could the last day stay open one more hour?"))
	choice("seojin", t("두 번째 달에 도와주신 거 아직도 고마워요. 그런데 부탁이 있어요. 마지막 날 22시부터 한 시간만 더 열 수 있을까요? 당일 폐기할 차 40세트가 있고, 아르바이트도 이미 불러 뒀어요.",
		"I'm still grateful for your help back in month two. I have a favor to ask: could we stay open one more hour from 22:00 on the last day? I have 40 tea sets that will be thrown away that day, and I've already booked part-timers."),
		"c05_extend", [
			["accept", t("운영표의 밤 담당이 있으니 한 시간 열어 드릴게요.", "The rota covers the night, so we'll open the extra hour.")],
			["reduce", t("기존 기능 안에서 30분, 남은 20세트만 열어 드릴게요.", "Thirty minutes within the existing features, for 20 sets.")],
			["decline", t("이번에는 준비된 범위를 넘어서 어려워요. 이유를 설명드릴게요.", "This time it's beyond what we prepared. Let me explain why.")]], {"channel": "connectly"})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d.get("key", "") != "c05_extend" or is_done("extend"):
				return
			var option := String(d["option"])
			Game.state["flags"]["c05_extend"] = option
			var night := String((Game.state["flags"].get("c05_rota", {}) as Dictionary).get("night", "hana"))
			match option:
				"accept":
					Game.relate("alex", {"agree": 1})
					if night == "me":
						Game.change_condition(-6)
						say("mina", t("연장 시간도 밤 담당인 당신 몫이에요. 목요일엔 꼭 쉬어요.", "The extra hour lands on you, since you have the night. Rest on Thursday, really."))
					else:
						say("hana", t("밤 담당이 그 한 시간도 같이 볼게요. 운영표에 적었어요.", "The night owner will cover that hour too. It's in the rota."))
				"reduce":
					say("seojin", t("30분이라도 고마워요. 남는 건 직원들이랑 나눠 마실게요.", "Even thirty minutes helps. We'll share the rest with the staff."), {"channel": "connectly"})
				"decline":
					Game.relate("alex", {"agree": -1})
					Game.state["flags"]["c05_seojin_followup"] = true
					say("seojin", t("아쉽네요. 저희 쪽 일정도 다시 바꿔야겠어요.", "That's a shame. I'll have to rearrange things on our side too."), {"channel": "connectly"})
			complete("extend")
			await wait(1.0)
			if is_current():
				_open()
		"site":
			if String(d.get("site", "")) == "campaign" and is_done("rush") and not is_done("watched"):
				complete("watched")
				_wrap()


## 20:00: the rush runs through the code in the repository right now.
func _open() -> void:
	if data().get("_opening", false) or is_done("rush"):
		return
	data()["_opening"] = true
	Game.set_time(20 * 60)
	monitor("payments", "ok", "normal")
	say("system", t("🌸 봄 한정 20시 오픈", "🌸 Spring limited — open at 20:00"), {"channel": "general"})
	var plan: Dictionary = (Game.state["flags"].get("c05_launch", {"stage": "ten", "limit": "keep"}) as Dictionary).duplicate()
	plan["extend"] = String(Game.state["flags"].get("c05_extend", "decline"))
	var r: Dictionary = await CampaignView.simulate(plan)
	data()["_opening"] = false
	if not is_current():
		return
	if not r.has("minutes"):
		r = {"errors": r.get("errors", []), "sold": 0, "stock": 120, "oversold": 0, "duplicateCharges": 0, "wrongPrice": 0, "reconcile": [], "minutes": []}
	Game.state["flags"]["c05_rush"] = r
	var bad := int(r.get("oversold", 0)) + int(r.get("duplicateCharges", 0)) + int(r.get("wrongPrice", 0)) + int(r.get("stuck", 0))
	Game.state["flags"]["c05_rush_clean"] = bad == 0 and (r.get("errors", []) as Array).is_empty()
	complete("rush")
	Game.advance(40)
	say("alex", {"ko": "📈 %s 품절! 누적 매출 %s. 다들 고생했어요!" % [String(r.get("soldOutAt", "-")), Game.won(int(r.get("revenue", 0)))],
		"en": "📈 Sold out at %s! Revenue %s. Great work, everyone!" % [String(r.get("soldOutAt", "-")), Game.won(int(r.get("revenue", 0)))]}, {"channel": "general"})
	if bad == 0:
		say("hana", t("(조용히) 알림 0건. 대기 안내는 잘 떴고, 조정 목록은 아침에 볼게요. 자러 갈게요.", "(quietly) Zero alerts. The waiting notice worked; I'll check the reconciliation list in the morning. Going to sleep."))
	else:
		say("hana", t("매출은 좋은데... 콘솔 숫자 좀 봐 줄래요? 내일 아침 보정할 게 있어요.", "Revenue looks great, but... could you check the console numbers? There's correcting to do in the morning."))
	say("mina", t("campaign.nexora.test에 오늘 밤 결과가 그대로 있어요. 그래프 말고 아래 숫자까지 봐요.", "Tonight's result is on campaign.nexora.test. Read past the graph to the numbers below it."))


func _wrap() -> void:
	if once("_reward"):
		Game.relate("alex", {"work": 3})
	if Game.state["flags"].get("c05_rush_clean", false):
		say("daniel", t("준비가 잘 되면 행사 날엔 아무 일도 안 일어나요. 그게 제일 좋은 결과예요.", "When the prep is good, nothing happens on the day. That's the best result there is."))
	else:
		say("daniel", t("숫자를 숨기지 않고 본 게 먼저예요. 내일 아침 보정 대상부터 정리해요.", "Looking at the numbers instead of hiding them comes first. Tomorrow morning we start with what needs correcting."))
	finish()


const CampaignView := preload("res://scripts/apps/campaign_view.gd")
