extends "res://scripts/story/mission.gd"
## C03 M05 — "but the tests passed". Buyers read the ship date as an arrival date.


func _init() -> void:
	id = "c03_05"
	chapter = 3
	day = 9
	issue = "NXR-045"
	title = t("테스트는 통과했는데요", "But the tests passed")
	objectives = [
		{"id": "talk", "text": t("Mina가 발견한 혼란에 답하기", "Respond to the confusion Mina found")},
		{"id": "sync", "text": t("main 최신화로 문구 테스트 받기", "Update main to get the wording tests")},
		{"id": "labelfix", "text": t("배송 예정 문구를 고치고 테스트 통과", "Fix the ship-date wording and pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "merged", "text": t("병합", "Merge")},
	]
	hints = [
		t("src/preorder/labels.ts의 문구만 고치면 돼요. 날짜는 '발송' 날짜이고, 받는 시점은 따로 안내해요.", "Only the wording in src/preorder/labels.ts changes. The date is when it ships; delivery timing is explained separately."),
	]


func begin() -> void:
	Game.set_time(15 * 60 + 30)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("mina", "main", {
			"src/preorder/labels.ts": Workspace.content("c03/labels.ts"),
			"tests/labels.test.ts": Workspace.content("c03/labels.test.ts"),
		}, "test(preorder): buyers read the ship date as an arrival date")
		if not is_current():
			return
		data()["_prepared"] = true
	if not Game.state["flags"].get("c03_beta_diverse", false):
		say("yuri", t("베타 문의가 몇 건 왔어요. 대부분 '언제 도착해요?'예요. 그리고 모자이크 마켓 해외 판매자들이 베타에 없어서, 정식 출시 때 마감 시간 문의가 몰릴 것 같다고 걱정하네요.",
			"A few beta inquiries came in, mostly 'when will it arrive?'. And since Mosaic's overseas sellers weren't in the beta, they worry about a wave of deadline questions at launch."))
		Game.relate("alex", {"work": -2})
	if not Game.pending_choice("c03_confused") and not is_done("talk"):
		choice("mina", t("실제 판매자 화면에서 봤는데요, 기술 규칙은 다 맞아요. 근데 구매자들이 '배송 예정일'을 받는 날로 읽어요. 그날 안 오면 문의가 와요. 테스트용 예시를 main에 올렸어요.",
			"I checked a real seller's screen. The rules are all correct, but buyers read 'ship date' as the day they receive it. When it doesn't arrive, they write in. I pushed example tests to main."),
			"c03_confused", [
				["wording", t("화면 문구가 오해를 만든 거네요. '발송 예정일'로 바꾸고 받는 시점을 따로 적을게요.", "The wording caused it. I'll say 'ships by' and explain delivery timing separately.")],
				["blame", t("구매자가 잘못 읽은 거 아닐까요? 날짜는 맞잖아요.", "Isn't that buyers misreading it? The date is correct.")]])


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d.get("key", "") != "c03_confused":
				return
			if d["option"] == "wording":
				Game.relate("mina", {"agree": 3, "work": 2})
				say("mina", t("고마워요. 같은 질문이 세 번 오면 그건 화면 문제라고 생각해요.", "Thanks. If the same question comes three times, I count it as a screen problem."))
			else:
				Game.relate("mina", {"agree": -3})
				say("mina", t("같은 질문이 세 번 왔으면 화면 문제예요. 사람 탓으로 정리하면 다음 주에도 같은 문의가 남아요.", "If the same question came three times, it's a screen problem. Blaming people leaves the same inquiry next week."))
			complete("talk")
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/labels.test.ts")):
				complete("labelfix")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				await wait(1.2)
				if not is_current():
					return
				say("yuri", t("지원 문서도 '발송 예정일'로 맞췄어요. 도착 문의가 줄 것 같아요.", "I updated the support doc to 'ships by'. Arrival questions should drop."))
				finish()
