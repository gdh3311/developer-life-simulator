extends "res://scripts/story/mission.gd"
## C04 M02 — author: Daniel Park. Find who wrote it with git, then ask about the background
## and the assumptions that changed, not who's to blame.


func _init() -> void:
	id = "c04_02"
	chapter = 4
	day = 11
	issue = "NXR-052"
	title = t("작성자 Daniel Park", "Author: Daniel Park")
	objectives = [
		{"id": "found", "text": t("git log 또는 git blame으로 환불 모듈 작성자 찾기", "Find the refund module's author with git log or git blame")},
		{"id": "asked", "app": "docs", "text": t("Docs에서 Daniel에게 할 질문 고르기", "Choose your questions for Daniel in Docs")},
	]
	hints = [t("터미널에서 git log -- src/refunds/refund.ts 또는 git blame src/refunds/refund.ts. Pork Git의 기록 탭에서도 볼 수 있어요.",
		"In Terminal: git log -- src/refunds/refund.ts or git blame src/refunds/refund.ts. Pork Git's history works too.")]
	forms_def = {
		"questions": {
			"title": t("Daniel에게 묻기", "Questions for Daniel"),
			"intro": t("오래된 결정을 이해하려면 당시 상황과 지금 바뀐 것을 나눠서 물어야 해요. 세 가지를 골라요.",
				"To understand an old decision, separate what was true then from what changed since. Pick three."),
			"submit": t("Daniel에게 보내기", "Send to Daniel"),
			"slots": [{"id": "q", "label": t("질문", "Questions"), "multi": true, "max": 3, "options": [
				{"id": "context", "text": t("2023년 첫 계약 때 판매자 수와 팀 인원은 어땠나요?", "How many sellers and engineers were there at the 2023 launch?")},
				{"id": "temporary", "text": t("10원 내림은 계약 조건이었나요, 임시 조치였나요?", "Was rounding down to 10 won a contract term or a stopgap?")},
				{"id": "changed", "text": t("지금은 그때와 무엇이 달라졌다고 보세요?", "What do you think has changed since then?")},
				{"id": "blame", "text": t("왜 이렇게 헷갈리게 짜셨어요?", "Why did you write it so confusingly?")},
				{"id": "rewrite", "text": t("그냥 다 새로 짜면 안 돼요?", "Can't we just rewrite it all?")},
			]}],
		},
	}


func open_forms() -> Array:
	return super.open_forms() if is_done("found") else []


func submit_form(form_id: String, picks: Dictionary) -> Array:
	if not is_done("found"):
		return [t("먼저 git으로 작성자를 확인하세요.", "Find the author with git first.")]
	return super.submit_form(form_id, picks)


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue(issue, title, "investigation", Game.L("나", "me"), "progress")
	say("alex", t("환불 모듈을 처음 만든 사람이 누구인지 알면 계약서 7조 얘기가 빨라질 것 같아요.", "If we knew who first wrote the refund module, the contract §7 discussion would go faster."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var q := FormRules.picked(picks, "q")
	var notes: Array = []
	if "blame" in q:
		notes.append(t("Mina: 그 질문은 사람을 향해요. 결정이 아니라요. Daniel이 방어부터 하게 될 거예요.", "Mina: That question targets the person, not the decision. Daniel will start defending instead of explaining."))
	if q.size() < 3:
		notes.append(t("질문 세 개를 골라 주세요.", "Pick three questions."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var q := FormRules.picked(picks, "q")
	Game.state["flags"]["c04_questions"] = q
	complete("asked")
	Game.advance(30)
	say("daniel", t("맞아요, 제가 썼어요. 그때 판매자는 열두 곳, 개발자는 저 혼자였고, 첫 계약서 7조에 10원 단위 내림이 있었어요. 임시가 아니라 계약이었죠. 다만 그 계약이 내년 3월에 끝나요.",
		"Yes, I wrote it. Back then there were twelve sellers, I was the only engineer, and §7 of the first contract required rounding down to 10 won. It was a contract term, not a hack. But that contract ends next March."))
	if "changed" in q:
		Game.relate("daniel", {"agree": 3, "tech": 2})
		say("daniel", t("바뀐 거요? 판매자가 400곳이 넘었고, 환불은 이제 정산팀이 매일 대조해요. 그때 가정이 하나도 안 남았네요.", "What changed? We're past 400 sellers, and finance reconciles refunds daily. None of the old assumptions hold."))
	if "rewrite" in q:
		Game.relate("daniel", {"agree": -2})
		say("daniel", t("새로 짜는 건 가능하죠. 다만 첫 계약 판매자 열두 곳이 내년 3월까지는 같은 숫자를 받아야 해요.", "We could rewrite it. But those twelve sellers need the same numbers until next March."))
	if Story.arcs.arc("legacy17") != null and Story.arcs.arc("legacy17").stage() >= 3:
		say("daniel", t("Hana 메모 봤어요. 결제 이력 테이블 얘기도 같은 시기 결정이에요. 그땐 다 '일단 돌아가게'였죠.", "I saw Hana's note. The payment history table was the same era. Back then everything was 'just make it work'."))
	Game.state["flags"]["c04_background"] = true
	finish()


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "command_finished" or is_done("found"):
		return
	var argv: Array = d.get("argv", [])
	var text := " ".join(argv.map(func(a) -> String: return String(a)))
	var out := String(d.get("out", ""))
	var about_refunds := "refund" in text or "refunds/refund.ts" in out or "partial refunds for the launch contract" in out
	if argv.size() >= 2 and String(argv[0]) == "git" and String(argv[1]) in ["log", "blame", "show"] and about_refunds and "Daniel" in out and int(d.get("code", 1)) == 0:
		complete("found")
		say("mina", t("작성자가... Daniel이네요? 물어볼 게 많겠어요. Docs에 질문을 정리해 봐요.", "The author is... Daniel? We'll have a lot to ask. Put your questions in Docs."))
