extends Node
## Global game state: the in-game clock (hybrid turn-based) and the current mission.
## Real Git / test events from Workspace are turned into story beats here.

signal time_changed(day: int, minutes: int)
signal message(app_id: String, title: String, body: String)
signal objectives_changed

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const DAY_START := 9 * 60

var day := 0
var minutes := DAY_START

## Chapter 1, Issue #001. Completion is judged by results (tests, Git state), not by exact code.
var objectives: Array[Dictionary] = [
	{"id": "tests", "text": "테스트 전부 통과시키기", "done": false},
	{"id": "branch", "text": "작업 브랜치 만들기", "done": false},
	{"id": "commit", "text": "작업 브랜치에 커밋하기", "done": false},
	{"id": "push", "text": "작업 브랜치 push 하기", "done": false},
]
var tests_passing := false
var _warned_main_commit := false


func _ready() -> void:
	Workspace.git_event.connect(_on_git_event)
	Workspace.tests_finished.connect(_on_tests_finished)


## Advance game time after a meaningful action (see GDD 7.1).
func advance(mins: int) -> void:
	minutes += mins
	time_changed.emit(day, minutes)


func next_day() -> void:
	day += 1
	minutes = DAY_START
	time_changed.emit(day, minutes)


func clock_text() -> String:
	return "%s %02d:%02d" % [DAY_NAMES[day % 7], floori(minutes / 60.0), minutes % 60]


func is_done(id: String) -> bool:
	for o in objectives:
		if o["id"] == id:
			return o["done"]
	return false


func _complete(id: String) -> void:
	for o in objectives:
		if o["id"] == id and not o["done"]:
			o["done"] = true
			message.emit("tasks", "이슈 #001 진행", "✓ " + String(o["text"]))
			objectives_changed.emit()
			if objectives.all(func(x: Dictionary) -> bool: return x["done"]):
				_on_mission_done()
			return


func _on_tests_finished(result: Dictionary) -> void:
	advance(5)
	var was_passing := tests_passing
	tests_passing = result.get("ok", false)
	if tests_passing:
		if not was_passing and not is_done("tests"):
			message.emit("chat", "Mina Choi", "방금 돌린 테스트 전부 통과했네요! 브랜치에 커밋해서 올려 주세요.")
		_complete("tests")


func _on_git_event(kind: String, detail: String) -> void:
	match kind:
		"branch_created":
			if detail != "main":
				_complete("branch")
		"committed":
			advance(10)
			if detail == "main":
				if not _warned_main_commit:
					_warned_main_commit = true
					message.emit("chat", "Daniel Park",
						"main에 바로 커밋하셨네요. 위키의 협업 규칙대로 작업 브랜치에서 진행해 주세요. (git switch -c 로 지금 커밋을 새 브랜치로 옮길 수 있어요)")
			else:
				_complete("commit")
		"pushed":
			advance(5)
			if detail == "main":
				return
			if not tests_passing:
				message.emit("chat", "Mina Choi", "%s 브랜치 올라온 거 봤는데, 테스트가 아직 실패하고 있어요. 확인 부탁드려요!" % detail)
			_complete("push")


func _on_mission_done() -> void:
	message.emit("chat", "Daniel Park", "브랜치 확인했습니다. 다음 단계는 PR이에요. PR 올려 주시면 리뷰할게요.")
