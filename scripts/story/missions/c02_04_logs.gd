extends "res://scripts/story/mission.gd"
## C02 M04 — the debug log printed buyer data. Keep only what tracing needs (an allowlist).


func _init() -> void:
	id = "c02_04"
	chapter = 2
	day = 6
	issue = "NXR-024"
	title = t("남겨야 할 로그", "Logs worth keeping")
	objectives = [
		{"id": "talk", "text": t("Mina와 로그에 남길 정보 정하기", "Agree with Mina on what the log keeps")},
		{"id": "sync", "text": t("main 최신화로 디버그 로그 코드 받기", "Update main to get the debug log code")},
		{"id": "logfix", "text": t("추적 정보만 남기도록 고치고 테스트 통과", "Keep only tracing fields and pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("git switch main → git pull로 src/orders/request_log.ts를 받으세요. Wiki '로그에 남길 것'에 기준이 있어요.", "git switch main → git pull to get src/orders/request_log.ts. The Wiki page 'What logs keep' has the rules."),
		t("지금 함수는 { ...event }로 전부 복사해요. 지울 필드를 고르는 대신 남길 필드만 골라서 새 객체를 만들어 보세요.", "The function copies everything with { ...event }. Instead of choosing fields to delete, build a new object with only the fields to keep."),
		t("예: return { requestId: event.requestId, shopId: event.shopId, result: event.result, attempt: event.attempt, durationMs: event.durationMs };", "e.g. return { requestId: event.requestId, shopId: event.shopId, result: event.result, attempt: event.attempt, durationMs: event.durationMs };"),
	]


func begin() -> void:
	Game.set_time(9 * 60 + 10)
	Game.add_issue(issue, title, "chore", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("mina", "main", {
			"src/orders/request_log.ts": Workspace.content("c02/request_log.ts"),
			"tests/request_log.test.ts": Workspace.content("c02/request_log.test.ts"),
		}, "chore(orders): debug request log used while reproducing NXR-021")
		if not is_current():
			return
		data()["_prepared"] = true
	say("system", t("두 번째 달 · 화요일", "Month two · Tuesday"), {"channel": "general", "silent": true})
	await wait(1.0)
	if not is_current():
		return
	if not Game.pending_choice("c02_log") and not is_done("talk"):
		choice("mina", t("어제 재현할 때 쓴 디버그 로그 봤어요? 주문 찾기엔 편한데... 테스트 구매자 이름이랑 주소, 결제 토큰까지 그대로 찍혀요. 주소까지 있어야 했나요?",
			"Did you see the debug log we used yesterday? Handy for finding orders, but it prints the test buyer's name, address and even the payment token. Did we need the address?"),
			"c02_log", [
				["minimal", t("요청 ID와 결과 코드만 남기겠습니다.", "I'll keep just the request ID and result code.")],
				["names", t("이름을 지우면 문의와 연결하기 어려울 것 같아요.", "Without names it'll be hard to connect logs to inquiries.")],
				["wipe", t("일단 전부 지우고 필요하면 다시 넣죠.", "Let's drop everything and add things back as needed.")]])


func hidden_tests() -> Dictionary:
	return load_tests("c02_04")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if not is_current():
		return
	CodeHub.review(p["id"], "daniel", "approved",
		t("허용 목록으로 바꿨네요. 다음에 이벤트에 필드가 늘어도 새지 않겠어요. 테스트까지 좋습니다." if touches else "허용 목록 방식 좋습니다. 로그 형식은 다음 사람도 보니까, 바꾼 이유를 PR에 남겨 둔 것도 좋네요.",
			"An allowlist. Fields added to the event later won't leak. Nice tests too." if touches else "Good call on the allowlist. Others will read these logs too, so the PR explanation helps."))


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d["key"] != "c02_log":
				return
			match d["option"]:
				"minimal":
					Game.relate("mina", {"work": 3})
					say("mina", t("좋아요. 다만 어느 상점의 요청인지, 재시도였는지, 얼마나 걸렸는지도 있어야 해요. 최소한으로 추적은 돼야 하니까요.",
						"Good. We also need which shop it was, whether it was a retry, and how long it took. It still has to be traceable."))
				"names":
					say("yuri", t("지원 도구에서는 권한 있는 사람이 주문 번호로 고객 정보를 볼 수 있어요. 로그에 한 벌 더 있을 필요는 없어요.",
						"In the support tool, authorized staff can look up customer details by order number. The log doesn't need another copy."))
				"wipe":
					Game.relate("daniel", {"agree": -1})
					say("daniel", t("다 지우면 다음에도 똑같이 막혀요. 이번 재현에 실제로 쓴 필드를 같이 골라 봅시다. Wiki에 기준을 적어 뒀어요.",
						"Dropping everything means we'll get stuck the same way next time. Let's pick the fields we actually used. I put the rules in the Wiki."))
			complete("talk")
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/request_log.test.ts")):
				complete("logfix")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("mina", {"tech": 4, "close": 2})
					Game.state["flags"]["c02_log_policy"] = true
				await wait(1.5)
				if not is_current():
					return
				say("mina", t("그럼 다음에 이 로그를 보는 사람이 제가 아니어도 찾겠네요. 고마워요.", "So the next person reading this log can find things even if it isn't me. Thanks."))
				finish()
