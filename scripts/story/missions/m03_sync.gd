extends "res://scripts/story/mission.gd"
## Day 1, 13:00 — After lunch: bring local main up to date.


func _init() -> void:
	id = "m03"
	day = 1
	title = "로컬 main 최신화"
	objectives = [
		{"id": "sync", "text": "로컬 main 최신화 (git switch main → git pull)"},
	]
	hints = [
		"병합은 CodeHub(원격 origin)에서 일어났어요. 내 PC의 main은 아직 예전 커밋에 머물러 있습니다.",
		"git switch main 으로 이동한 뒤 git pull 을 실행하세요. git log --oneline 으로 병합 커밋을 확인할 수 있어요.",
	]


func begin() -> void:
	Game.set_time(13 * 60)
	await wait(1.0)
	say("system", "점심시간이 끝났습니다. 13:00", {"channel": "general", "silent": true})
	say("daniel", "첫 PR 병합 축하해요. 병합은 원격에서 일어났으니 로컬 main도 최신으로 받아 두세요. (git switch main → git pull)")
	if await Workspace.local_main_synced():
		_done()


func on_event(kind: String, _d: Dictionary) -> void:
	if kind.begins_with("git_") and not is_done("sync") and await Workspace.local_main_synced():
		_done()


func _done() -> void:
	complete("sync")
	Game.relate("daniel", {"work": 2})
	await wait(1.0)
	say("daniel", "좋아요. 다음 업무 전까지 코드베이스를 둘러보세요. git log -p 로 다른 사람 커밋을 읽어 보는 것도 공부가 돼요.")
	finish()
