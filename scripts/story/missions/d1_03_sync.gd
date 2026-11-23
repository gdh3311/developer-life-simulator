extends "res://scripts/story/mission.gd"
## Day 1, afternoon — Tutorial: bring main up to date and clean up the merged branch.


func _init() -> void:
	id = "d1_03"
	day = 1
	tutorial = true
	title = t("병합 후 정리", "Clean up after a merge")
	objectives = [
		{"id": "sync", "app": "terminal",
			"text": t("로컬 main 최신화", "Update your local main"),
			"guide": t("병합은 원격(CodeHub)에서 일어났어요. 내 컴퓨터의 main은 아직 예전 상태예요.\n  git switch main\n  git pull",
				"The merge happened on the remote. Your local main is still old.\n  git switch main\n  git pull")},
		{"id": "cleanup", "app": "terminal",
			"text": t("병합된 작업 브랜치 지우기", "Delete the merged branch"),
			"guide": t("다 쓴 브랜치는 정리해요:\n  git branch -d docs/fix-typo\n  git branch 로 남은 브랜치를 확인해 보세요.",
				"Tidy up branches you're done with:\n  git branch -d docs/fix-typo\nThen run git branch to see what's left.")},
	]


func begin() -> void:
	Story.side.fire_if_pending("d1_lunch")
	while Game.pending_choice("d1_lunch"):
		await wait(0.5)
	Game.set_time(13 * 60 + 30)
	await wait(1.0)
	say("daniel", t("점심 잘 먹었어요? 오후엔 정리부터 하죠. 병합된 PR은 로컬 main도 최신으로 받아 두고, 다 쓴 브랜치는 지우는 습관을 들여요.",
		"Good lunch? Let's tidy up first. After a merge, update your local main and delete the branch you no longer need."))
	if await Workspace.local_main_synced():
		complete("sync")


func on_event(kind: String, d: Dictionary) -> void:
	if kind.begins_with("git_") or kind == "cmd":
		if not is_done("sync") and await Workspace.local_main_synced():
			complete("sync")
		if kind == "cmd" and is_git(d["argv"], "branch") and is_done("sync"):
			var branches := await Workspace.local_branches()
			if not branches.any(func(b: String) -> bool: return b.begins_with("docs/")):
				complete("cleanup")
	if all_done() and not data().get("finished", false):
		data()["finished"] = true
		Game.relate("daniel", {"work": 2})
		await wait(1.0)
		say("alex", t("첫날 고생 많았어요! 오늘은 여기까지예요. 내일부터 진짜 버그를 맡게 될 거예요. 상단의 '퇴근하기'를 누르세요.",
			"Great first day! That's it for today. Tomorrow you'll get a real bug. Press 'Clock out' at the top."))
		finish()
