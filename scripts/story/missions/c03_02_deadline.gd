extends "res://scripts/story/mission.gd"
## C03 M02 — same time, different date. Seller time zones and the exact deadline minute.


func _init() -> void:
	id = "c03_02"
	chapter = 3
	day = 8
	issue = "NXR-042"
	title = t("같은 시각 다른 날짜", "Same time, different date")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 마감 처리 코드 받기", "Update main to get the deadline code")},
		{"id": "deadline", "text": t("판매자 시간대와 마감 정각을 처리하고 테스트 통과", "Handle seller time zones and the exact deadline; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 시간대 검증 통과", "Pass the additional CI time-zone checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("git switch main → git pull로 src/preorder/deadline.ts를 받으세요. Wiki '예약 판매 마감 시각'에 규칙이 있어요.", "git switch main → git pull to get src/preorder/deadline.ts. Rules are in the Wiki page 'Pre-order deadlines'."),
		t("지금 코드는 판매자 현지 시각을 UTC로 착각해요. UTC = 현지 시각 - 오프셋(분)이에요.", "The code treats the seller's local time as UTC. UTC = local time - offset (minutes)."),
		t("마감 시각 그 분부터는 닫혀야 해요. <= 와 < 의 차이를 보세요.", "Orders close at the deadline minute itself. Look at <= versus <."),
	]
	ai_task = {
		"label": t("판매자 시간대 마감 처리", "Seller time-zone deadline handling"),
		"files": {"src/preorder/deadline.ts": "c03/deadline_ai.ts"},
		"bases": {"src/preorder/deadline.ts": "c03/deadline.ts"},
		"summary": t("판매자 오프셋을 반영해 UTC로 바꿨습니다. 마감 정각의 경계는 검증하지 않았습니다.", "Converted to UTC using the seller offset. The exact-deadline boundary was not validated."),
	}


func begin() -> void:
	Game.set_time(13 * 60)
	Game.add_issue(issue, title, "feature", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/preorder/deadline.ts": Workspace.content("c03/deadline.ts"),
			"tests/deadline.test.ts": Workspace.content("c03/deadline.test.ts"),
		}, "feat(preorder): deadline skeleton with examples")
		if not is_current():
			return
		data()["_prepared"] = true
	say("daniel", t("마감 처리 뼈대랑 예제 테스트 올렸어요. 판매자는 자기 시간으로 마감을 적고, 서버는 UTC로 비교해요. 지금 코드는 그걸 섞어 쓰고 있어요.",
		"I pushed a deadline skeleton with example tests. Sellers write deadlines in their own time; the server compares UTC. The current code mixes them up."))
	await wait(1.5)
	if not is_current():
		return
	if not Game.pending_choice("c03_wording") and not data().has("wording"):
		choice("sophie", t("화면 문구 정해야 해요! '자정 마감'이 제일 짧은데, 그걸로 할까요?", "We need the screen wording! 'Closes at midnight' is shortest. Shall we use it?"), "c03_wording", [
			["seller", t("'3월 10일 23:00 (판매자 시간)까지'처럼 시각과 기준을 같이 써요.", "Write the time and its basis: 'until Mar 10, 23:00 (seller time)'.")],
			["midnight", t("짧은 게 좋죠. 자정으로 해요.", "Short is good. Midnight it is.")]])


func hidden_tests() -> Dictionary:
	return load_tests("c03_02")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d.get("key", "") != "c03_wording":
				return
			data()["wording"] = d["option"]
			if d["option"] == "seller":
				Game.relate("sophie", {"agree": 3})
				say("sophie", t("좋아요. 그럼 코드도 '그 분부터 닫힘' 하나만 지키면 화면이랑 맞겠네요.", "Nice. Then the code only has to keep 'closed from that minute' to match the screen."))
			else:
				say("sophie", t("음... 자정이 0시인지 24시인지 판매자마다 다르게 읽겠네요. 그냥 '23:00 (판매자 시간)까지'로 쓸게요.", "Hmm... sellers will read midnight as 0:00 or 24:00 differently. I'll write 'until 23:00 (seller time)'."))
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/deadline.test.ts")):
				complete("deadline")
		"ai_used":
			data()["ai_used"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and once("_ai_note"):
				say("ai", t("CI에서 '마감 정각에는 이미 닫혀 있다' 검사가 실패했어요. 설명에 적은 대로 정각 경계를 검증하지 않았습니다.",
					"CI failed 'the exact deadline minute is already closed'. As noted, I didn't validate the exact boundary."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("daniel", {"tech": 4})
					Game.relate("sophie", {"close": 2})
				await wait(1.2)
				if not is_current():
					return
				say("daniel", t("해외 판매자 시간대까지 맞네요. 이 경계는 나중에 국제 정산에서도 다시 만날 거예요.", "Overseas seller time zones work too. You'll meet this boundary again in international settlement."))
				finish()
