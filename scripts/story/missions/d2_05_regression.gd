extends "res://scripts/story/mission.gd"
## Day 2, 16:00 — Sophie's nickname feature brought the #001 bug back (GDD: "첫 번째 사건").


func _init() -> void:
	id = "d2_05"
	day = 2
	title = t("16시의 사건", "The 4 PM incident")
	issue = "#005"
	objectives = [
		{"id": "sync", "text": t("최신 main 받기 (git pull)", "Get the latest main (git pull)")},
		{"id": "cause", "text": t("원인 커밋 찾기 (git log / git blame / git show)", "Find the culprit commit (git log / git blame / git show)")},
		{"id": "tests", "text": t("테스트 전부 통과시키기 (닉네임 테스트 포함)", "Make all tests pass (including the nickname test)")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open a fix PR")},
		{"id": "ci", "text": t("CI 통과", "CI passes")},
		{"id": "merged", "text": t("병합 (Daniel)", "Merged (by Daniel)")},
	]
	hints = [
		t("git switch main → git pull 로 오늘 오후에 들어온 변경을 받은 뒤 npm test 를 돌려 보세요.", "git switch main → git pull to get this afternoon's changes, then run npm test."),
		t("git log --oneline 이나 git blame src/users/displayName.ts 로 누가 언제 이 줄을 바꿨는지 볼 수 있어요.", "git log --oneline or git blame src/users/displayName.ts shows who changed these lines and when."),
		t("Sophie의 닉네임 기능은 유지해야 합니다 (되돌리면 CI가 실패해요). 닉네임도 trim 하고, 비어 있으면 #001 이름 규칙으로 넘어가게 하세요.",
			"Keep Sophie's nickname feature (reverting it fails CI). Trim the nickname too, and fall back to the #001 rules when it's blank."),
	]


func begin() -> void:
	Game.set_time(16 * 60)
	if not data().get("_prepared", false):
		await Workspace.bot_commit("sophie", "main", {
			"src/users/displayName.ts": Workspace.content("m04/displayName.ts"),
			"tests/nickname.test.ts": Workspace.content("m04/nickname.test.ts"),
		}, "feat(users): support nickname on profile (#3)")
		if not is_current():
			return
		data()["_prepared"] = true
	Game.add_issue("#005", Game.LL("닉네임 배포 후 프로필 이름 'undefined' 재발", "'undefined' is back on profiles after the nickname release"), "bug", Game.L("나", "me"), "progress")
	monitor("api", "warn", "profile_bug")
	await wait(1.0)
	if not is_current():
		return
	say("mina", t("급해요! 방금 배포된 버전에서 이름이 다시 'undefined Choi'로 나와요. #005로 올렸어요.", "Urgent! The build that just shipped shows 'undefined Choi' again. Filed as #005."))
	await wait(2.5)
	if not is_current():
		return
	say("alex", t("내일 오전에 고객 데모가 있어요. 오늘 안에 해결 가능할까요?", "We have a customer demo tomorrow morning. Can this be fixed today?"))
	await wait(2.5)
	if not is_current():
		return
	say("sophie", t("헉, 혹시 제 닉네임 기능 때문일까요..? 머지 전에 테스트를 못 돌렸어요 ㅠㅠ", "Oh no, is it my nickname feature..? I didn't run the tests before merging :("))


func hidden_tests() -> Dictionary:
	return load_tests("m04")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if not is_current():
		return
	CodeHub.review(p["id"], "daniel", "approved",
		t("닉네임 기능은 살리면서 회귀를 막았네요. 테스트까지 좋습니다.", "You kept the nickname feature and stopped the regression, with tests. Nice.") if touches
		else t("수정 확인했습니다. 다음엔 이번 회귀 케이스를 테스트로 남겨 두면 좋겠어요.", "Fix confirmed. Next time, leave this regression case behind as a test."))
	if touches:
		Game.relate("daniel", {"tech": 5})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"command_finished":
			if int(d.get("code", -1)) != 0:
				return
			var argv: Array = d["argv"]
			if is_git(argv, "log") or is_git(argv, "blame") or is_git(argv, "show"):
				complete("cause")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				monitor("api", "ok", "normal")
				if once("_merge_reward"):
					Game.relate("mina", {"work": 5})
					Game.relate("alex", {"work": 5})
				await wait(1.5)
				if not is_current():
					return
				say("mina", t("확인했어요! 닉네임도, 이름 없는 프로필도 모두 정상입니다.", "Confirmed! Nicknames and empty-name profiles both look right."))
				await wait(2.0)
				if not is_current():
					return
				choice("sophie", t("도와주셔서 고마워요... 제가 테스트를 안 돌리고 머지해서 일이 커졌네요.", "Thanks for the help... It blew up because I merged without running the tests."), "d2_sophie", [
					["kind", t("괜찮아요! 다음엔 머지 전에 같이 테스트 돌려봐요.", "It's okay! Let's run the tests together before merging next time.")],
					["firm", t("다음부턴 머지 전에 테스트는 꼭 돌려 주세요.", "Please always run the tests before merging from now on.")]])
		"choice":
			if d["key"] == "d2_sophie":
				if d["option"] == "kind":
					Game.relate("sophie", {"close": 8, "agree": 3})
				else:
					Game.relate("sophie", {"work": 3, "close": -2})
					Game.relate("daniel", {"agree": 3})
				await wait(1.5)
				if not is_current():
					return
				say("daniel", t("오늘 버그 두 개 잡았네요. 수고했어요. 퇴근하세요.", "Two bugs fixed today. Good work. Go home."))
				finish()
