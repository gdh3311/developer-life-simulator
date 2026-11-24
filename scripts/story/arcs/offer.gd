extends "res://scripts/story/arc.gd"
## Storyline A — "A different desk": Jamie (Brightloop) coffee chat → take-home brief.
## Chapter 3 covers the invite, the coffee chat and the take-home brief; the task itself is Chapter 4.


func _init() -> void:
	id = "offer"
	npc = "recruiter"
	title = t("다른 책상 · Brightloop", "A different desk · Brightloop")
	stages = [t("제안 전", "Not offered yet"), t("커피챗 예정", "Coffee chat planned"),
		t("커피챗 완료 · 과제 안내 대기", "Coffee chat done · waiting for the take-home"),
		t("과제 일정 확정 (챕터 4)", "Take-home scheduled (Chapter 4)")]
	beats = [
		["invite", 8, 12 * 60 + 10, false],
		["invite2", 9, 12 * 60 + 10, false],
		["coffee", 9, 18 * 60 + 20, true],
		["task", 10, 19 * 60, false],
	]


func evening_label(_beat: String) -> Dictionary:
	return t("Jamie와 커피챗 (Brightloop)", "Coffee chat with Jamie (Brightloop)")


func can_fire(beat: String) -> bool:
	match beat:
		"invite":
			return status() == "locked"
		"invite2":
			return status() == "deferred"
		"coffee":
			return is_active() and stage() == 1
		"task":
			return is_active() and stage() == 2
	return false


func _opening() -> Dictionary:
	var flags: Dictionary = Game.state["flags"]
	if flags.get("offer_stage", "") == "interview" or flags.get("ending", "") == "left":
		return t("지난번에 이어서 이야기 나누기로 했었죠. 이번엔 커피 한잔하면서 하고 싶은 일을 들어 보고 싶어요.",
			"We said we'd keep talking. This time I'd like to hear what you want to work on, over coffee.")
	if Game.state["connectly"].get("offer", "") == "decline":
		return t("예전에 정중히 거절하셨죠. 그 뒤 공개 포트폴리오에 올린 주문 중복 회고를 보고 다시 연락드려요. 커피 한잔 어떠세요?",
			"You politely declined before. I saw the duplicate-order write-up on your public portfolio and wanted to reach out again. Coffee?")
	return t("Brightloop의 Jamie예요. 공개 포트폴리오 보고 연락드려요. 부담 없이 커피 한잔하면서 이야기 나눠요.",
		"Jamie from Brightloop. I saw your public portfolio. No pressure: let's talk over coffee.")


func fire(beat: String) -> void:
	match beat:
		"invite":
			choice("recruiter", _opening(), "arc_offer_invite", [
				["accept", t("좋아요, 이번 주에 시간 내 볼게요.", "Sure, I'll make time this week.")],
				["later", t("이번 주는 출시라서요. 내일 다시 이야기해요.", "It's launch week. Let's talk tomorrow.")],
				["decline", t("감사하지만 지금은 지금 회사에 집중할게요.", "Thanks, but I'm focusing on my current team for now.")]], {"channel": "connectly"})
		"invite2":
			choice("recruiter", t("출시 잘 되고 있어요? 오늘 저녁이나 내일 잠깐이라도 괜찮아요.", "How's the launch going? Even a short chat tonight or tomorrow works."),
				"arc_offer_invite2", [
					["accept", t("네, 잠깐 이야기해요.", "Okay, let's talk briefly.")],
					["decline", t("이번에는 넘어갈게요. 연락 고마워요.", "I'll pass this time. Thanks for reaching out.")]], {"channel": "connectly"})
		"coffee":
			say("recruiter", t("와 주셔서 고마워요. 연봉은 비교하기 쉬워요. 그래서 하고 싶은 일부터 묻고 싶어요.",
				"Thanks for coming. Pay is easy to compare, so I'd like to start with what you want to do."), {"channel": "connectly"})
			choice("recruiter", t("요즘 일에서 가장 더 하고 싶은 게 뭐예요?", "What do you most want more of in your work?"), "arc_offer_want", [
				["depth", t("한 시스템을 깊게 이해하고 책임지는 일", "Understanding one system deeply and owning it")],
				["product", t("고객 문제를 처음부터 끝까지 맡는 일", "Owning a customer problem end to end")],
				["pay", t("솔직히 보상이 제일 커요", "Honestly, compensation matters most")]], {"channel": "connectly"})
		"task":
			choice("recruiter", t("과제 안내예요: 주문 이벤트 중복 제거, 기한은 다음 주 금요일이에요. 지금 회사의 코드나 자료는 쓰지 마세요. 공개된 지식이면 충분해요.",
				"Here's the take-home: deduplicate order events, due next Friday. Don't use your current company's code or data; public knowledge is enough."),
				"arc_offer_task", [
					["weekend", t("주말에 하겠습니다.", "I'll do it over the weekend.")],
					["extend", t("이번 주 출시가 있어서 기한을 한 주 늘릴 수 있을까요?", "I have a launch this week; could I get one more week?")],
					["withdraw", t("생각해 보니 지금은 아닌 것 같아요. 여기서 멈출게요.", "On reflection, now isn't the time. I'll stop here.")]], {"channel": "connectly"})


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	match String(d.get("key", "")):
		"arc_offer_invite", "arc_offer_invite2":
			match d["option"]:
				"accept":
					if Story.arcs.accept(id):
						say("recruiter", t("좋아요! 내일 저녁 6시 반 어떠세요? 회사 근처 카페로 갈게요.", "Great! How about 6:30 tomorrow evening? I'll come to a café near your office."), {"channel": "connectly"})
						if d["key"] == "arc_offer_invite2":
							# Accepted a day late: the coffee chat happens over lunch instead.
							var moved: Dictionary = data().get("moved", {})
							moved["coffee"] = [Game.day(), 12 * 60 + 40]
							data()["moved"] = moved
				"later":
					Story.arcs.defer(id)
					say("recruiter", t("물론이죠. 내일 다시 연락드릴게요.", "Of course. I'll check in tomorrow."), {"channel": "connectly"})
				"decline":
					Story.arcs.drop(id)
					say("recruiter", t("알겠어요. 필요해지면 언제든 연락 주세요.", "Understood. Reach out anytime if that changes."), {"channel": "connectly"})
		"arc_offer_want":
			data()["want"] = d["option"]
			choice("recruiter", t("반대로 다음 회사에서는 하고 싶지 않은 일도 있어요? 그게 면담에서 더 중요할 때가 많아요.",
				"And what do you not want to do next? That often matters more in interviews."), "arc_offer_avoid", [
					["oncall", t("설명 없이 밤마다 장애만 받는 역할", "A role that only takes night-time pages with no context")],
					["silo", t("고객을 한 번도 못 보는 일", "Work where I never see the customer")],
					["handwave", t("이유 없이 정해진 일정만 따르는 일", "Following deadlines set without reasons")]], {"channel": "connectly"})
		"arc_offer_avoid":
			data()["avoid"] = d["option"]
			Game.advance(30)
			say("recruiter", t("솔직하게 말해 줘서 고마워요. 그게 맞는 팀을 찾는 데 제일 도움이 돼요. 과제 안내를 곧 보낼게요.",
				"Thanks for being candid. That helps the most in finding the right team. I'll send the take-home brief soon."), {"channel": "connectly"})
			set_stage(2)
		"arc_offer_task":
			data()["task"] = d["option"]
			match d["option"]:
				"weekend":
					Game.change_condition(-5)
					say("recruiter", t("좋아요. 막히는 게 있으면 질문 주세요. 질문도 평가에 들어가요, 좋은 쪽으로요.", "Great. Ask if you get stuck. Questions count too, in a good way."), {"channel": "connectly"})
					set_stage(3)
				"extend":
					say("recruiter", t("그럼요. 출시 끝나고 하세요. 기한은 다다음 주 금요일로 바꿀게요.", "Of course. Finish the launch first. I'll move the deadline a week."), {"channel": "connectly"})
					set_stage(3)
				"withdraw":
					Story.arcs.drop(id)
					say("recruiter", t("알겠어요. 이야기 나눠서 즐거웠어요. 또 봬요.", "Understood. I enjoyed talking. See you around."), {"channel": "connectly"})


func summary() -> String:
	if status() == "dropped":
		return Game.L("Brightloop 이야기는 여기서 멈췄다", "The Brightloop conversation stopped here")
	if status() in ["locked", "deferred"] and stage() == 0:
		return Game.L("Jamie의 제안은 아직 열려 있다", "Jamie's offer is still open")
	return super.summary()
