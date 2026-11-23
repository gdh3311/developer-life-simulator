extends "res://scripts/story/mission.gd"
## Day 1, 16:00 — Sophie's nickname feature reintroduced the #001 bug (GDD: "첫 번째 사건").


func _init() -> void:
	id = "m04"
	day = 1
	title = "16시의 사건"
	issue = "#005"
	objectives = [
		{"id": "sync", "text": "최신 main 받기 (git pull)"},
		{"id": "cause", "text": "원인 커밋 찾기 (git log / git blame / git show)"},
		{"id": "tests", "text": "테스트 전부 통과시키기 (닉네임 테스트 포함)"},
		{"id": "pr", "text": "수정 PR 만들기"},
		{"id": "ci", "text": "CI 통과"},
		{"id": "merged", "text": "PR 병합하기"},
	]
	hints = [
		"git switch main → git pull 로 오늘 오후에 들어온 변경을 받은 뒤 npm test 를 돌려 보세요.",
		"git log --oneline 이나 git blame src/users/displayName.ts 로 누가 언제 이 줄을 바꿨는지 볼 수 있어요.",
		"Sophie의 닉네임 기능은 유지해야 합니다 (되돌리면 CI가 실패해요). 닉네임도 trim 하고, 비어 있으면 #001 이름 규칙으로 넘어가게 하세요.",
		"예: const nick = (user.nickname ?? '').trim();\nif (nick) return nick;\n// 그 다음 #001 규칙",
	]


func begin() -> void:
	Game.set_time(16 * 60)
	await Workspace.bot_commit("sophie", "main", {
		"src/users/displayName.ts": Workspace.content("m04/displayName.ts"),
		"tests/nickname.test.ts": Workspace.content("m04/nickname.test.ts"),
	}, "feat(users): support nickname on profile (#3)")
	Game.add_issue("#005", "닉네임 배포 후 프로필 이름 'undefined' 재발", "bug", "나", "progress")
	monitor("api", "warn", "profile_bug")
	await wait(1.0)
	say("mina", "급해요! 방금 배포된 버전에서 이름이 다시 'undefined Choi'로 나와요. #005로 올렸어요.")
	await wait(2.5)
	say("alex", "내일 오전에 고객 데모가 있어요. 오늘 안에 해결 가능할까요?")
	await wait(2.5)
	say("sophie", "헉, 혹시 제 닉네임 기능 때문일까요..? 머지 전에 테스트를 못 돌렸어요 ㅠㅠ")


func hidden_tests() -> Dictionary:
	return load_tests("m04")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	CodeHub.review(p["id"], "daniel", "approved",
		"닉네임 기능은 살리면서 회귀를 막았네요. 테스트까지 좋습니다." if touches else "수정 확인했습니다. 다음엔 이번 회귀 케이스를 테스트로 남겨 두면 좋겠어요.")
	if touches:
		Game.relate("daniel", {"tech": 5})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"cmd":
			var argv: Array = d["argv"]
			if argv.size() >= 2 and argv[0] == "git" and argv[1] in ["log", "blame", "show"]:
				complete("cause")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				monitor("api", "ok", "normal")
				Game.relate("mina", {"work": 5})
				Game.relate("alex", {"work": 5})
				await wait(1.5)
				say("mina", "확인했어요! 닉네임도, 이름 없는 프로필도 모두 정상입니다.")
				await wait(2.0)
				choice("sophie", "도와주셔서 고마워요... 제가 테스트를 안 돌리고 머지해서 일이 커졌네요.", "m04_sophie", [
					["kind", "괜찮아요! 다음엔 머지 전에 같이 테스트 돌려봐요."],
					["firm", "다음부턴 머지 전에 테스트는 꼭 돌려 주세요."]])
		"choice":
			if d["key"] == "m04_sophie":
				if d["option"] == "kind":
					Game.relate("sophie", {"close": 8, "agree": 3})
				else:
					Game.relate("sophie", {"work": 3, "close": -2})
					Game.relate("daniel", {"agree": 3})
				await wait(1.5)
				say("daniel", "첫날부터 버그를 두 개나 잡았네요. 오늘은 여기까지 하고 퇴근하세요.")
				finish()
