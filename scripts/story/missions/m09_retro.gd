extends "res://scripts/story/mission.gd"
## Day 3, 17:00 — Blameless retro and the first performance review. Chapter end.


func _init() -> void:
	id = "m09"
	day = 3
	title = "회고와 성과 면담"
	objectives = [
		{"id": "retro", "text": "장애 회고에서 의견 내기 (#general)"},
		{"id": "review", "text": "Alex와 1:1 성과 면담"},
	]


func begin() -> void:
	Game.set_time(17 * 60)
	await wait(1.0)
	var options := [
		["process", "타임아웃·에러 케이스 테스트를 CI 필수 항목으로 추가하자고 제안한다"],
		["blame", "원인이 된 코드를 작성한 사람을 찾아 책임을 묻자고 한다"],
	]
	if Game.stat("ai_used") > 0:
		options.append(["ai", "AI가 작성한 코드에 대한 리뷰 체크리스트를 만들자고 제안한다"])
	choice("alex", "오늘 장애 회고를 짧게 할게요. 원인과 재발 방지책을 어떻게 정리하면 좋을까요?", "m09_retro", options,
		{"channel": "general"})


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	if d["key"] == "m09_retro":
		match d["option"]:
			"process":
				Game.relate("daniel", {"tech": 4, "agree": 5})
				Game.relate("alex", {"work": 3})
				say("mina", "좋아요! QA 쪽에서도 장애 케이스를 테스트로 정리해 둘게요.", {"channel": "general"})
			"blame":
				Game.relate("mina", {"close": -6})
				Game.relate("sophie", {"close": -8})
				Game.relate("alex", {"agree": -3})
				say("alex", "음... 회고는 사람이 아니라 시스템을 고치는 자리예요. 비난 없는 회고로 가죠.", {"channel": "general"})
			"ai":
				Game.relate("alex", {"work": 4})
				Game.relate("daniel", {"agree": 4, "tech": 3})
				say("sophie", "저도 AI 코드 리뷰할 때 그 체크리스트 쓰고 싶어요!", {"channel": "general"})
		complete("retro")
		await wait(2.5)
		_performance_review()
	elif d["key"] == "m09_review":
		complete("review")
		finish()


func _performance_review() -> void:
	var total := 0
	var count := 0
	for npc in Game.state["rel"]:
		for key in Game.REL_KEYS:
			total += Game.rel(npc, key)
			count += 1
	var avg := float(total) / count
	var promoted := avg >= 48.0 and Game.stat("main_commits") <= 1
	Game.state["flags"]["review_avg"] = avg
	if promoted:
		Game.state["rank"] = 2
	var lines: Array = []
	lines.append("3일 동안 정말 많은 일이 있었죠. 팀 평균 신뢰도는 %d점이에요." % roundi(avg))
	if Game.stat("ci_fail") <= 2:
		lines.append("CI를 거의 깨뜨리지 않은 점이 인상적이었어요.")
	if Game.stat("main_commits") > 0:
		lines.append("main 직접 커밋은 앞으로 조심해 주세요.")
	if Game.stat("ai_used") > 0:
		lines.append("AI를 활용하면서도 결과를 검증한 점 좋았어요.")
	lines.append("결과적으로 %s" % ("Junior Developer II 로 승급입니다! 축하해요." if promoted else "조금만 더 신뢰를 쌓으면 승급할 수 있을 거예요."))
	choice("alex", " ".join(lines), "m09_review", [["thanks", "감사합니다! 다음 주도 잘 부탁드려요."]])
