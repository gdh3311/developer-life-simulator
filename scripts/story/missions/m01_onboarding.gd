extends "res://scripts/story/mission.gd"
## Day 1, 09:00 — First day at NEXORA.


func _init() -> void:
	id = "m01"
	day = 1
	title = "첫 출근"
	objectives = [
		{"id": "hello", "text": "TeamChat에서 Alex에게 인사하기"},
		{"id": "wiki", "text": "Wiki에서 프로젝트 개요 읽기"},
		{"id": "tasks", "text": "TaskBoard에서 내 업무 확인하기"},
	]
	hints = [
		"화면 아래 독에서 말풍선 아이콘(TeamChat)을 열고 Alex의 메시지에 답해 보세요.",
		"책 아이콘이 Wiki, 칸반 아이콘이 TaskBoard 입니다.",
	]


func begin() -> void:
	Game.add_issue("#001", "프로필 이름이 비어 있으면 'undefined' 표시", "bug", "나", "todo")
	Game.add_issue("#002", "로그인 타임아웃 처리 (1차)", "bug", "Daniel", "done")
	Game.add_issue("#003", "주문 목록 페이지네이션", "feature", "Sophie", "progress")
	await wait(1.2)
	say("system", "오늘부터 NEXORA 개발팀에 합류한 New Hire 님을 환영합니다!", {"channel": "general", "silent": true})
	choice("alex", "NEXORA에 오신 걸 환영해요! 오늘 첫 출근이죠? Wiki에서 프로젝트 개요부터 보고, TaskBoard에서 첫 업무를 확인해 주세요 :)",
		"m01_hello", [["warm", "안녕하세요! 잘 부탁드립니다 :)"], ["ready", "네, 바로 확인하겠습니다."]])


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d["key"] == "m01_hello":
				if d["option"] == "warm":
					Game.relate("alex", {"close": 4})
				else:
					Game.relate("alex", {"work": 3})
				complete("hello")
		"app_opened":
			if d["app"] == "wiki":
				complete("wiki")
			elif d["app"] == "tasks":
				complete("tasks")
	if all_done():
		finish()
