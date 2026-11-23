extends "res://scripts/story/mission.gd"
## Day 4, 17:00 — Blameless retro, performance review (Intern → Junior), and the job offer decision.


func _init() -> void:
	id = "d4_10"
	day = 4
	title = t("회고와 성과 면담", "Retro and performance review")
	objectives = [
		{"id": "retro", "text": t("장애 회고에서 의견 내기 (#general)", "Speak up in the incident retro (#general)")},
		{"id": "review", "text": t("Alex와 1:1 성과 면담", "1:1 performance review with Alex")},
	]


func begin() -> void:
	Game.set_time(17 * 60)
	await wait(1.0)
	if not is_current():
		return
	var options := [
		["process", t("타임아웃·에러 케이스 테스트를 CI 필수 항목으로 추가하자고 제안한다", "Propose making timeout/error-case tests mandatory in CI")],
		["blame", t("원인이 된 코드를 작성한 사람을 찾아 책임을 묻자고 한다", "Suggest finding who wrote the code and holding them accountable")],
	]
	if Game.stat("ai_used") > 0:
		options.append(["ai", t("AI가 작성한 코드에 대한 리뷰 체크리스트를 만들자고 제안한다", "Propose a review checklist for AI-written code")])
	choice("alex", t("오늘 장애 회고를 짧게 할게요. 원인과 재발 방지책을 어떻게 정리하면 좋을까요?", "Quick incident retro. How should we capture the cause and prevent a repeat?"),
		"d4_retro", options, {"channel": "general"})


func resume() -> void:
	if is_done("review"):
		_finish_offer()
	elif is_done("retro") and not Game.state["chat"].any(func(m: Dictionary) -> bool: return m["key"] == "d4_review"):
		_performance_review()


func _finish_offer() -> void:
	if Game.state["flags"].get("offer_interest", false):
		Story.side.fire_if_pending("final_offer")
		while Game.pending_choice("final_offer"):
			await wait(0.5)
			if not is_current():
				return
	finish()


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	match d["key"]:
		"d4_retro":
			match d["option"]:
				"process":
					Game.relate("daniel", {"tech": 4, "agree": 5})
					Game.relate("alex", {"work": 3})
					say("mina", t("좋아요! QA 쪽에서도 장애 케이스를 테스트로 정리해 둘게요.", "Great! QA will turn the incident cases into tests too."), {"channel": "general"})
				"blame":
					Game.relate("mina", {"close": -6})
					Game.relate("sophie", {"close": -8})
					Game.relate("alex", {"agree": -3})
					say("alex", t("음... 회고는 사람이 아니라 시스템을 고치는 자리예요. 비난 없는 회고로 가죠.", "Hmm... retros fix systems, not people. Let's keep it blameless."), {"channel": "general"})
				"ai":
					Game.relate("alex", {"work": 4})
					Game.relate("daniel", {"agree": 4, "tech": 3})
					say("sophie", t("저도 AI 코드 리뷰할 때 그 체크리스트 쓰고 싶어요!", "I want to use that checklist when reviewing AI code too!"), {"channel": "general"})
			complete("retro")
			await wait(2.5)
			if not is_current():
				return
			_performance_review()
		"d4_review":
			complete("review")
			if Game.state["flags"].get("offer_interest", false):
				await wait(2.0)
				if not is_current():
					return
				Story.side.fire_if_pending("final_offer")
				while Game.pending_choice("final_offer"):
					await wait(0.5)
					if not is_current():
						return
			finish()


func _performance_review() -> void:
	var total := 0
	var count := 0
	for npc in Game.state["rel"]:
		for key in Game.REL_KEYS:
			total += Game.rel(npc, key)
			count += 1
	var avg := float(total) / count
	var caught := Game.stat("caught_slacking")
	var promoted := avg >= 24.0 and Game.stat("main_commits") <= 1 and caught <= 1
	Game.state["flags"]["review_avg"] = avg
	if promoted:
		Game.state["rank"] = 1
		Game.emit_event("promoted", {})
	var ko: Array = ["4일 동안 많은 일이 있었죠. 팀 평균 신뢰도는 %d점이에요." % roundi(avg)]
	var en: Array = ["A lot happened in four days. Your average team trust is %d." % roundi(avg)]
	if Game.stat("test_runs") > 0:
		ko.append("테스트로 결과를 확인하며 문제를 해결한 점이 좋았어요.")
		en.append("It was good to see you use tests to verify your work.")
	if Game.stat("main_commits") > 0:
		ko.append("main 직접 커밋은 앞으로 조심해 주세요.")
		en.append("Please be careful about committing to main.")
	if caught > 0:
		ko.append("근무 중 딴짓하다 걸린 건... 다들 알고 있어요.")
		en.append("And slacking off during work... everyone noticed.")
	if Game.stat("ai_used") > 0:
		ko.append("AI를 활용하면서도 결과를 검증한 점 좋았어요.")
		en.append("Using AI while still verifying its output was good.")
	ko.append("인턴 기간 평가 결과, 주니어 개발자로 정규직 전환입니다! 축하해요." if promoted else "아직은 신뢰를 더 쌓아야 해요. 인턴 기간을 한 달 연장할게요.")
	en.append("Your internship review: you're converted to a full-time Junior Developer! Congrats." if promoted else "You need to build more trust first. We're extending your internship by a month.")
	choice("alex", t(" ".join(ko), " ".join(en)), "d4_review", [["thanks", t("감사합니다! 다음 주도 잘 부탁드려요.", "Thank you! Looking forward to next week.")]])
