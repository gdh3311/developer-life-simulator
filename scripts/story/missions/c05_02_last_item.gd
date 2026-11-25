extends "res://scripts/story/mission.gd"
## C05 M02 — the last item in stock. Holds must claim before any await, expire on a virtual clock,
## and release when the audit log fails. Hidden CI checks expiry and the audit failure.


func _init() -> void:
	id = "c05_02"
	chapter = 5
	day = 14
	issue = "NXR-062"
	title = t("마지막 한 개의 재고", "The last item in stock")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 재고 예약 모듈 받기", "Update main to get the inventory module")},
		{"id": "holdfix", "text": t("동시 예약이 마지막 한 개를 넘지 않게 고치고 테스트 통과", "Keep concurrent holds from overselling the last item; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("Wiki '캠페인 준비 > 재고 예약'을 보세요. 남은 수량을 확인한 뒤 await가 끝나기 전에 다른 요청도 같은 수량을 봐요.", "See Wiki 'Campaign prep > Inventory holds'. Between the check and the await, other requests see the same count."),
		t("holds.set을 await 앞으로 옮기고, 감사 로그가 실패하면 다시 지워요. 만료된 예약은 available()을 계산하기 전에 정리해요.", "Move holds.set before the await and delete it again if the audit fails. Clear expired holds before computing available()."),
	]
	ai_task = {
		"label": t("캠페인 재고 동시 예약", "Concurrent campaign holds"),
		"files": {"src/inventory/reserve.ts": "c05/reserve_ai.ts"},
		"bases": {"src/inventory/reserve.ts": "c05/reserve.ts"},
		"summary": t("await 전에 선점하도록 바꿨습니다. 예약 만료와 감사 로그 실패는 검증하지 않았습니다.",
			"Claims before the await now. Hold expiry and audit-log failures were not validated."),
	}


func begin() -> void:
	Game.set_time(11 * 60)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/inventory/reserve.ts": Workspace.content("c05/reserve.ts"),
			"tests/reserve.test.ts": Workspace.content("c05/reserve.test.ts"),
		}, "feat(inventory): campaign holds (10 min before payment)")
		if not is_current():
			return
		data()["_prepared"] = true
	say("daniel", t("작년에 재고가 -14까지 내려갔어요. 예약 모듈을 main에 올렸는데, 동시 예약 테스트가 빨간불이에요. 마지막 한 개에 세 명이 동시에 들어오면 셋 다 성공해요.",
		"Last year stock went down to -14. I pushed the holds module to main, but the concurrency test is red: three people on the last item all succeed."))
	if Story.status("c02_06") == "done":
		say("daniel", t("두 번째 달에 요청 키를 원자적으로 선점했던 거 기억나요? 같은 생각이에요. 확인과 선점 사이에 기다리는 틈을 없애요.",
			"Remember claiming request keys atomically back in month two? Same idea: no waiting gap between the check and the claim."))


func hidden_tests() -> Dictionary:
	return load_tests("c05_02")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/reserve.test.ts")):
				complete("holdfix")
		"ai_used":
			data()["ai_used"] = true
			Game.state["flags"]["c05_reserve_ai"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and once("_ai_note"):
				say("ai", t("CI가 예약 만료와 감사 로그 실패에서 실패했어요. 설명에 적은 대로 그 두 경우는 검증하지 않았습니다.", "CI failed on hold expiry and audit-log failures. As noted, I didn't validate those two cases."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("daniel", {"tech": 3})
				await wait(1.2)
				if not is_current():
					return
				say("hana", t("campaign.nexora.test에서 리허설을 돌릴 수 있게 되면 이 숫자부터 볼게요. 초과 판매 0, 만료 안 된 예약에 묶인 재고 0.",
					"Once the rehearsal runs on campaign.nexora.test, these are the first numbers I'll check: oversold 0, stock stuck in holds 0."))
				finish()
