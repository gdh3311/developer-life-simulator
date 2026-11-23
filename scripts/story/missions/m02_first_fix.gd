extends "res://scripts/story/mission.gd"
## Day 1, 09:15 — Issue #001: first bug fix, first PR, first code review (GDD Chapter 1).


func _init() -> void:
	id = "m02"
	day = 1
	title = "첫 버그 수정"
	issue = "#001"
	objectives = [
		{"id": "tests", "text": "npm test 로 버그 확인 후 테스트 전부 통과시키기"},
		{"id": "branch", "text": "작업 브랜치 만들기 (git switch -c ...)"},
		{"id": "commit", "text": "작업 브랜치에 커밋하기"},
		{"id": "push", "text": "작업 브랜치 push 하기"},
		{"id": "pr", "text": "CodeHub에서 Pull Request 만들기"},
		{"id": "ci", "text": "CI 통과"},
		{"id": "approved", "text": "Daniel의 리뷰 승인 받기"},
		{"id": "merged", "text": "PR 병합하기"},
	]
	hints = [
		"터미널에서 npm test 를 실행하면 어떤 입력에서 실패하는지 보여요. Wiki의 '사용자 이름 표시 규칙'과 비교해 보세요.",
		"DevIDE에서 src/users/displayName.ts 를 고치고 Ctrl+S로 저장하세요. 각 이름을 trim() 하고, 빈 값은 빼고, 남은 걸 공백 하나로 이으면 됩니다.",
		"예: const parts = [user.firstName, user.lastName].map((p) => (p ?? '').trim()).filter((p) => p.length > 0);\nreturn parts.length > 0 ? parts.join(' ') : 'Unknown User';",
		"고친 뒤: git switch -c fix/display-name → git add . → git commit -m \"fix: ...\" → git push → CodeHub에서 PR 만들기",
	]


func begin() -> void:
	Game.set_time(9 * 60 + 15)
	await wait(1.5)
	say("mina", "안녕하세요! QA 민아예요. 이슈 #001 부탁드려요. 이름이 비어 있는 사용자 프로필에 'undefined'가 보여요. 재현 테스트는 tests/displayName.test.ts 에 넣어 뒀으니 터미널에서 npm test 로 확인해 보세요!")


func hidden_tests() -> Dictionary:
	return load_tests("m02")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if touches:
		CodeHub.review(p["id"], "daniel", "approved", "엣지 케이스 테스트까지 추가했네요. 깔끔합니다. 승인할게요.")
		Game.relate("daniel", {"tech": 6, "work": 3})
		return
	if data().get("argued", false):
		return
	if data().get("asked_tests", false):
		CodeHub.review(p["id"], "daniel", "changes", "아직 테스트 변경이 보이지 않네요. tests/ 에 케이스를 추가해서 push 해 주세요.")
		return
	data()["asked_tests"] = true
	CodeHub.review(p["id"], "daniel", "changes",
		"동작은 하지만 회귀 테스트가 없네요. 위키 협업 규칙에 '버그 수정 PR에는 회귀 테스트를 포함한다'고 되어 있어요.",
		{"key": "m02_review", "choices": [
			{"id": "fix", "label": "테스트 케이스를 추가하겠습니다."},
			{"id": "argue", "label": "Mina님이 올린 재현 테스트가 이미 이 버그를 커버합니다."}]})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d["key"] == "m02_review":
				if d["option"] == "argue":
					data()["argued"] = true
					Game.relate("daniel", {"agree": 5, "tech": 3})
					CodeHub.review(int(d["pr"]), "daniel", "approved",
						"...맞네요. Mina님 테스트가 정확히 이 버그를 재현하고 있군요. 승인합니다. 다음엔 엣지 케이스 하나쯤은 직접 추가해 봐요.")
				else:
					Game.relate("daniel", {"work": 3})
					CodeHub.comment(int(d["pr"]), "daniel", "좋아요. push 하면 다시 볼게요.")
		"git_committed":
			if d["branch"] == "main" and not data().get("warned_main", false):
				data()["warned_main"] = true
				Game.relate("daniel", {"work": -3})
				say("daniel", "main에 바로 커밋하셨네요. 위키 협업 규칙대로 작업 브랜치에서 진행해 주세요. (git switch -c 새브랜치 로 지금 커밋을 그대로 가져갈 수 있어요)")
		"git_pushed":
			if d["branch"] != "main" and not data().get("tests_ok", false) and not data().get("warned_red", false):
				data()["warned_red"] = true
				Game.relate("mina", {"work": -2})
				say("mina", "%s 브랜치 올라온 거 봤는데, 로컬 테스트가 아직 실패하고 있지 않나요? 확인 부탁드려요!" % d["branch"])
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				Game.relate("mina", {"work": 5, "close": 2})
				await wait(1.5)
				say("mina", "dev 서버 배포 확인했어요. 이름 없는 프로필도 이제 정상으로 나와요. 감사합니다!")
				finish()
