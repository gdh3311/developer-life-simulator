extends RefCounted
## Side events: small interactions with teammates that happen around the missions
## (lunch, coffee chats, questions, status check-ins, job offers on Connectly).

static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


## [id, day, minutes (time it becomes due), requires mission active (or "")]
const SCHEDULE := [
	["d1_lunch", 1, 11 * 60 + 50, ""],
	["d1_connect", 1, 13 * 60 + 40, ""],
	["d2_coffee", 2, 10 * 60 + 30, ""],
	["d2_quiz", 2, 14 * 60, ""],
	["d3_checkin", 3, 11 * 60, "d3_07"],
	["d3_offer", 3, 15 * 60, ""],
]


func _fired() -> Dictionary:
	return Game.state["side"]


func check() -> void:
	for e in SCHEDULE:
		if _fired().has(e[0]) or Game.day() != e[1] or Game.minutes() < e[2]:
			continue
		if e[3] != "" and (Story.active == null or Story.active.id != e[3]):
			continue
		fire(e[0])


## End of the day: anything scheduled for today that hasn't happened yet happens now.
func flush_day() -> void:
	for e in SCHEDULE:
		if not _fired().has(e[0]) and Game.day() == e[1] and e[3] == "":
			fire(e[0])


func fire_if_pending(id: String) -> void:
	if not _fired().has(id):
		fire(id)


func _choice(from: String, text: Dictionary, key: String, options: Array, channel := "") -> void:
	var opts := {"key": key, "choices": options.map(func(c: Array) -> Dictionary: return {"id": c[0], "label": c[1]})}
	if channel != "":
		opts["channel"] = channel
	Game.say(from, text, opts)


func fire(id: String) -> void:
	_fired()[id] = true
	match id:
		"d1_lunch":
			_choice("mina", t("Sophie랑 점심 먹으러 가는데 같이 가요! 근처에 맛있는 국밥집 있어요.", "Sophie and I are heading to lunch. Join us! There's a great soup place nearby."), id, [
				["join", t("좋아요, 같이 가요!", "Sure, let's go!")],
				["skip", t("일이 좀 밀려서요... 다음에 꼭 같이 가요.", "I'm a bit behind... next time for sure.")]])
		"d1_connect":
			_choice("daniel", t("Connectly에서 1촌 신청 보냈어요. 팀원들끼리는 다 연결돼 있어요.", "Sent you a Connectly request. The whole team is connected there."), id, [
				["accept", t("수락할게요!", "Accepted!")]], "connectly")
		"d2_coffee":
			_choice("daniel", t("잠깐 커피 한잔 할래요? 5분만요. 어제 PR 얘기도 좀 하고.", "Want to grab a quick coffee? Five minutes. We can talk about yesterday's PR."), id, [
				["go", t("네, 좋아요!", "Yes, sounds good!")],
				["busy", t("지금은 버그 보고 있어서요, 다음에요.", "I'm in the middle of a bug. Another time?")]])
		"d2_quiz":
			_choice("sophie", t("저 궁금한 게 있는데요... git merge랑 rebase 차이가 뭐예요? 맨날 헷갈려요.", "Quick question... what's the difference between git merge and rebase? I always mix them up."), id, [
				["right", t("merge는 두 기록을 합치는 커밋을 만들고, rebase는 내 커밋을 다른 브랜치 끝으로 다시 쌓아요.", "merge creates a commit that joins two histories; rebase replays my commits on top of the other branch.")],
				["wrong", t("결과는 똑같아요. 아무거나 써도 돼요.", "They do the same thing. Use whichever.")],
				["brush", t("음... 검색해 보세요!", "Hmm... just search it!")]])
		"d3_checkin":
			_choice("alex", t("배송비 작업 진행 어때요? 몇 시쯤 끝날 것 같아요?", "How's the shipping work going? Roughly when will it be done?"), id, [
				["real", t("테스트까지 하면 오후 2시쯤이요.", "Around 2 PM, including tests.")],
				["over", t("30분이면 돼요!", "Thirty minutes, tops!")]])
		"d3_offer":
			_choice("recruiter", t("안녕하세요 %s 님, Brightloop의 Jamie입니다. 최근 활동을 보고 연락드려요. 저희 백엔드 팀에서 주니어 개발자를 찾고 있는데, 현재보다 연봉 15%% 이상 제안 가능합니다. 관심 있으실까요?" % Game.pname(),
				"Hi %s, I'm Jamie from Brightloop. I saw your recent activity. Our backend team is hiring a junior engineer, and we can offer 15%%+ above your current pay. Interested?" % Game.pname()), id, [
				["interested", t("관심 있어요. 얘기 나눠 보고 싶어요.", "I'm interested. Let's talk.")],
				["decline", t("감사하지만 지금 회사에서 더 배우고 싶어요.", "Thanks, but I want to keep learning where I am.")],
				["later", t("나중에 다시 연락드릴게요.", "I'll get back to you later.")]], "connectly")
		"final_offer":
			_choice("recruiter", t("면접 결과가 좋아서 정식 오퍼를 드리려고 해요. Brightloop 주니어 백엔드, 연봉 +18%. 금요일까지 답 주실 수 있을까요?",
				"Your interviews went well, so here's a formal offer: Junior Backend at Brightloop, +18% pay. Can you answer by Friday?"), id, [
				["accept", t("오퍼를 수락할게요.", "I accept the offer.")],
				["stay", t("고민해 봤는데, NEXORA에 남을게요.", "I thought about it. I'm staying at NEXORA.")]], "connectly")


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "pr_merged" and Game.state["flags"].has("promised_by") and Story.active != null and Story.active.id == "d3_07":
		if int(d["pr"]) == int(Story.active.data().get("pr", -1)) and Game.minutes() > int(Game.state["flags"]["promised_by"]):
			Game.state["flags"].erase("promised_by")
			Game.relate("alex", {"work": -8, "agree": -3})
			Game.say("alex", t("30분이면 된다고 하셨잖아요... 데모 일정 다시 잡느라 고생했어요. 다음엔 현실적으로 말해 주세요.",
				"You said thirty minutes... I had to reshuffle the demo. Please give me realistic estimates next time."))
	if kind != "choice":
		return
	var opt: String = d["option"]
	match d["key"]:
		"d1_lunch":
			if opt == "join":
				Game.relate("mina", {"close": 4})
				Game.relate("sophie", {"close": 4})
				Game.change_condition(15)
				Game.say("sophie", t("여기 진짜 맛있죠? 오후도 화이팅이에요!", "Isn't this place great? Good luck this afternoon!"), {"silent": true})
			else:
				Game.relate("mina", {"close": -1})
				Game.change_condition(-5)
		"d1_connect":
			Game.relate("daniel", {"close": 1})
			Game.state["connectly"]["connections"] = int(Game.state["connectly"].get("connections", 3)) + 1
		"d2_coffee":
			if opt == "go":
				Game.relate("daniel", {"close": 5, "agree": 2})
				Game.change_condition(10)
				Game.advance(15)
				Game.say("daniel", t("팁 하나 줄게요. PR은 작게, 설명은 자세히. 그것만 지켜도 리뷰어가 좋아해요.", "One tip: keep PRs small and descriptions detailed. Reviewers will love you for it."))
			else:
				Game.relate("daniel", {"close": -1, "work": 1})
		"d2_quiz":
			match opt:
				"right":
					Game.relate("sophie", {"tech": 5, "close": 3})
					Game.say("sophie", t("아하! 그래서 공유 브랜치에서는 rebase를 조심하라는 거군요. 고마워요!", "Oh! That's why you should be careful rebasing shared branches. Thanks!"))
				"wrong":
					Game.relate("sophie", {"tech": -3})
					Game.say("sophie", t("음... Daniel은 다르다고 했던 것 같은데. 제가 한번 찾아볼게요.", "Hmm... Daniel said they were different, I think. I'll look it up."))
				"brush":
					Game.relate("sophie", {"close": -4})
		"d3_checkin":
			if opt == "real":
				Game.relate("alex", {"work": 2})
			else:
				Game.relate("alex", {"work": 2})
				Game.state["flags"]["promised_by"] = Game.minutes() + 60
		"d3_offer":
			Game.state["connectly"]["offer"] = opt
			if opt == "interested":
				Game.state["flags"]["offer_interest"] = true
				Game.say("recruiter", t("좋아요! 다음 주에 가볍게 커피챗 일정 잡을게요.", "Great! I'll set up a casual chat next week."), {"channel": "connectly"})
		"final_offer":
			Game.state["flags"]["ending"] = "left" if opt == "accept" else "stayed"
			if opt == "accept":
				Game.relate("alex", {"close": -5})
				Game.say("alex", t("...아쉽네요. 짧았지만 같이 일해서 좋았어요. 새 회사에서도 잘할 거예요.", "...That's a shame. It was short, but good working with you. You'll do great there."))
			else:
				Game.relate("alex", {"close": 4, "work": 3})
