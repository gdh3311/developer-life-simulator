extends "res://scripts/story/mission.gd"
## Day 2, 09:15 — Issue #001: first real bug, first tests, first code review (GDD Chapter 1).


func _init() -> void:
	id = "d2_04"
	day = 2
	title = t("첫 버그 수정", "First bug fix")
	issue = "#001"
	objectives = [
		{"id": "sync", "text": t("git pull 로 Mina가 올린 재현 테스트 받기", "git pull to get Mina's reproduction tests")},
		{"id": "tests", "text": t("npm test 로 버그 확인 후 테스트 전부 통과시키기", "Reproduce with npm test, then make every test pass")},
		{"id": "branch", "text": t("작업 브랜치 만들기", "Create a working branch")},
		{"id": "commit", "text": t("작업 브랜치에 커밋하기", "Commit on the branch")},
		{"id": "push", "text": t("push 하기", "Push it")},
		{"id": "pr", "text": t("PR 만들기", "Open a PR")},
		{"id": "ci", "text": t("CI 통과", "CI passes")},
		{"id": "approved", "text": t("Daniel의 승인 받기", "Get Daniel's approval")},
		{"id": "merged", "text": t("병합 (Daniel)", "Merged (by Daniel)")},
	]
	hints = [
		t("git switch main → git pull 로 새 테스트를 받고, npm test 로 어떤 입력에서 실패하는지 보세요. Wiki '사용자 이름 표시 규칙'과 비교해 보세요.",
			"git switch main → git pull to get the new tests, then npm test to see which inputs fail. Compare with the Wiki's 'Display name rules'."),
		t("DevIDE에서 src/users/displayName.ts 를 고치세요. 각 이름을 trim() 하고, 빈 값은 빼고, 남은 걸 공백 하나로 이으면 됩니다.",
			"Edit src/users/displayName.ts in DevIDE: trim() each part, drop empty ones, and join the rest with one space."),
		t("예: const parts = [user.firstName, user.lastName].map((p) => (p ?? '').trim()).filter((p) => p.length > 0);\nreturn parts.length > 0 ? parts.join(' ') : 'Unknown User';",
			"e.g. const parts = [user.firstName, user.lastName].map((p) => (p ?? '').trim()).filter((p) => p.length > 0);\nreturn parts.length > 0 ? parts.join(' ') : 'Unknown User';"),
	]


func begin() -> void:
	Game.set_time(9 * 60 + 15)
	Game.add_issue("#001", Game.LL("프로필 이름이 비어 있으면 'undefined' 표시", "Profile shows 'undefined' when the name is empty"), "bug", Game.L("나", "me"), "progress")
	await Workspace.bot_commit("mina", "main", {"tests/displayName.test.ts": Workspace.content("m02/displayName.test.ts")},
		"test(users): reproduce #001 display name bug")
	await wait(1.2)
	say("system", t("DAY 2 · 화요일 아침입니다.", "DAY 2 · Tuesday morning."), {"channel": "general", "silent": true})
	say("mina", t("안녕하세요! QA Mina예요. 이슈 #001 부탁드려요. 이름이 비어 있는 프로필에 'undefined'가 보여요. 재현 테스트를 main에 올려 뒀으니 pull 받고 npm test 로 확인해 보세요!",
		"Hi! I'm Mina from QA. Could you take issue #001? Profiles with an empty name show 'undefined'. I pushed reproduction tests to main, so pull and run npm test!"))


func hidden_tests() -> Dictionary:
	return load_tests("m02")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if touches:
		CodeHub.review(p["id"], "daniel", "approved", t("엣지 케이스 테스트까지 추가했네요. 깔끔합니다. 승인하고 병합할게요.", "You even added an edge-case test. Clean. Approving and merging."))
		Game.relate("daniel", {"tech": 6, "work": 3})
		return
	if data().get("argued", false):
		return
	if data().get("asked_tests", false):
		CodeHub.review(p["id"], "daniel", "changes", t("아직 테스트 변경이 보이지 않네요. tests/ 에 케이스를 추가해서 push 해 주세요.", "I still don't see test changes. Add a case under tests/ and push."))
		Game.relate("daniel", {"work": -2})
		return
	data()["asked_tests"] = true
	CodeHub.review(p["id"], "daniel", "changes",
		t("동작은 하지만 회귀 테스트가 없네요. 위키 협업 규칙에 '버그 수정 PR에는 회귀 테스트를 포함한다'고 되어 있어요.",
			"It works, but there's no regression test. The Wiki rules say 'bug-fix PRs include a regression test'."),
		{"key": "d2_review", "choices": [
			{"id": "fix", "label": t("테스트 케이스를 추가하겠습니다.", "I'll add a test case.")},
			{"id": "argue", "label": t("Mina님이 올린 재현 테스트가 이미 이 버그를 커버합니다.", "Mina's reproduction tests already cover this bug.")}]})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d["key"] == "d2_review":
				if d["option"] == "argue":
					data()["argued"] = true
					Game.relate("daniel", {"agree": 4, "tech": 2})
					CodeHub.review(int(d["pr"]), "daniel", "approved",
						t("...맞네요. Mina님 테스트가 정확히 이 버그를 재현하고 있군요. 승인합니다. 다음엔 엣지 케이스 하나쯤은 직접 추가해 봐요.",
							"...Fair. Mina's tests reproduce exactly this bug. Approved. Next time, add at least one edge case yourself."))
				else:
					Game.relate("daniel", {"work": 2})
					CodeHub.comment(int(d["pr"]), "daniel", t("좋아요. push 하면 다시 볼게요.", "Good. I'll look again once you push."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				Game.relate("mina", {"work": 5, "close": 2})
				await wait(1.5)
				say("mina", t("dev 서버 배포 확인했어요. 이름 없는 프로필도 이제 정상이에요. 감사합니다!", "Verified on the dev server. Empty-name profiles look right now. Thanks!"))
				finish()
