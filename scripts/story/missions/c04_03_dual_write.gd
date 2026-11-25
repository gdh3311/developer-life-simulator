extends "res://scripts/story/mission.gd"
## C04 M03 — why write it twice. ATLAS stage 1: dual write that never loses a comparison record.


func _init() -> void:
	id = "c04_03"
	chapter = 4
	day = 12
	issue = "NXR-053"
	title = t("두 번 적는 이유", "Why write it twice")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 이중 기록 초안 받기", "Update main to get the dual-write draft")},
		{"id": "dualfix", "text": t("실패를 숨기지 않고 재처리 목록에 남기고 테스트 통과", "Queue failures for retry instead of hiding them; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("Wiki 'ATLAS 이중 기록'을 보세요. 기존 저장소가 기준이고, 원장 실패는 partial + 재처리 목록이에요.", "See the Wiki page 'ATLAS dual write'. The old store is the source of truth; a ledger failure is partial plus a retry entry."),
		t("try/catch로 원장 실패를 받되, 같은 id는 재처리 목록에 한 번만 넣어요. 기존 저장소 실패는 failed예요.", "Catch the ledger failure, but queue an id only once. An old-store failure is 'failed'."),
	]
	ai_task = {
		"label": t("ATLAS 이중 기록 실패 처리", "ATLAS dual-write failure handling"),
		"files": {"src/atlas/dual_write.ts": "c04/dual_write_ai.ts"},
		"bases": {"src/atlas/dual_write.ts": "c04/dual_write.ts"},
		"summary": t("원장 실패를 기록하고 재처리 목록에 넣었습니다. 기존 저장소 실패와 중복 재처리는 검증하지 않았습니다.",
			"Logs ledger failures and queues them for retry. Old-store failures and duplicate retries were not validated."),
	}


func begin() -> void:
	Game.set_time(9 * 60 + 10)
	Game.add_issue(issue, title, "feature", Game.L("나", "me"), "progress")
	say("system", t("일곱 번째 달 · 화요일", "Month seven · Tuesday"), {"channel": "general", "silent": true})
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/atlas/dual_write.ts": Workspace.content("c04/dual_write.ts"),
			"tests/dual_write.test.ts": Workspace.content("c04/dual_write.test.ts"),
		}, "feat(atlas): dual-write draft for comparison records")
		if not is_current():
			return
		data()["_prepared"] = true
	say("daniel", t("ATLAS 첫 조각이에요. 환불 기록을 기존 저장소와 새 원장에 같이 적어요. 전환은 안 해요. 비교용이에요. 그런데 제 초안은 원장 실패를 그냥 삼켜요. 그러면 나중에 비교할 수가 없죠.",
		"The first piece of ATLAS: write refund records to both the old store and the new ledger. No cutover, just comparison. My draft swallows ledger failures, though. Then we can't compare anything later."))


func hidden_tests() -> Dictionary:
	return load_tests("c04_03")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/dual_write.test.ts")):
				complete("dualfix")
		"ai_used":
			data()["ai_used"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and once("_ai_note"):
				say("ai", t("CI가 기존 저장소 실패와 중복 재처리에서 실패했어요. 설명에 적은 대로 그 두 경우는 검증하지 않았습니다.", "CI failed on old-store failures and duplicate retries. As noted, I didn't validate those two cases."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("daniel", {"tech": 4})
				await wait(1.2)
				if not is_current():
					return
				say("daniel", t("이제 원장이 조용히 비지 않겠네요. 재처리 목록은 전환 판단 때 제일 먼저 볼 숫자예요.", "Now the ledger won't silently go empty. The retry list is the first number we'll look at when deciding the cutover."))
				say("mina", t("Relay에서 atlas.nexora.test 열어 보세요. 이번 주 환불 기록을 지금 main 코드로 다시 돌려 볼 수 있어요. 원장 꺼졌던 세 건이 어디 갔는지 보여요.",
					"Open atlas.nexora.test in Relay. It replays this week's refunds through the current code, so you can see where the three records from the ledger outage went."))
				finish()
