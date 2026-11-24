extends "res://scripts/story/mission.gd"
## C03 M07 — next week it's still my job. Owner, hours, shared channel and a runbook.


func _init() -> void:
	id = "c03_07"
	chapter = 3
	day = 10
	issue = "NXR-047"
	title = t("다음 주에도 내 일", "Still my job next week")
	objectives = [
		{"id": "own", "app": "docs", "text": t("Docs에서 담당·문의 시간·채널·운영 설명서 정하기", "Set owner, hours, channel and runbook in Docs")},
	]
	hints = [
		t("개인 메시지로 문의를 받으면 그 사람이 쉬는 날 기능도 쉬어요. 공용 채널과 정해진 시간이 필요해요.", "If questions come by DM, the feature rests whenever that person does. You need a shared channel and set hours."),
	]
	forms_def = {
		"own": {
			"title": t("예약 판매 운영 담당", "Pre-order ownership"),
			"intro": t("출시가 끝나도 문의와 수정은 계속 와요. 누가, 언제, 어디서 받는지 정합니다.", "Questions and fixes keep coming after launch. Decide who handles them, when and where."),
			"submit": t("팀에 공유", "Share with the team"),
			"slots": [
				{"id": "owner", "label": t("담당", "Owner"), "options": [
					{"id": "me", "text": t("내가 담당", "Me")},
					{"id": "pair", "text": t("서버는 내가, 화면은 Sophie가", "Me for the server, Sophie for the screens")},
					{"id": "none", "text": t("출시가 끝났으니 따로 두지 않음", "None; the launch is done")}]},
				{"id": "hours", "label": t("문의 받는 시간", "Inquiry hours"), "options": [
					{"id": "set", "text": t("화·목 14~16시, 장애는 온콜", "Tue/Thu 14:00–16:00; outages go to on-call")},
					{"id": "always", "text": t("언제든지", "Anytime")}]},
				{"id": "channel", "label": t("문의 채널", "Channel"), "options": [
					{"id": "shared", "text": t("#preorder 공용 채널", "#preorder shared channel")},
					{"id": "dm", "text": t("나에게 개인 메시지", "DM me")}]},
				{"id": "runbook", "label": t("운영 설명서", "Runbook"), "options": [
					{"id": "now", "text": t("지금 작성해서 Wiki에 올림", "Write it now and post it in the Wiki")},
					{"id": "later", "text": t("시간 날 때 작성", "Write it when there's time")}]},
			],
		},
	}


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	say("yuri", t("출시 축하해요! 그런데 벌써 판매자 질문이 저한테 개인 메시지로 와요. 이건 누구한테 넘기면 돼요?",
		"Congrats on the launch! But seller questions are already arriving in my DMs. Who should I pass them to?"))
	say("sophie", t("저도 화면 질문 두 개 받았어요ㅠ", "I got two screen questions too ㅠ"))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes: Array = []
	if FormRules.picked(picks, "owner")[0] == "none":
		notes.append(t("Daniel: 담당이 비면 질문은 결국 가장 착한 사람에게 개인 메시지로 가요. 지금 Yuri처럼요.", "Daniel: Without an owner, questions end up in the kindest person's DMs. Like Yuri's right now."))
	if FormRules.picked(picks, "hours")[0] == "always":
		notes.append(t("Daniel: '언제든'은 결국 '아무 때도 집중 못 함'이에요. 시간을 정하고 급한 건 온콜로 보내요.", "Daniel: 'Anytime' means 'never focused'. Set hours and route urgent things to on-call."))
	if FormRules.picked(picks, "channel")[0] == "dm":
		notes.append(t("Yuri: 개인 메시지면 당신이 쉬는 날 기능도 쉬어요. 다른 사람도 답을 볼 수 있게 공용 채널로 해요.", "Yuri: With DMs, the feature takes a day off whenever you do. Use a shared channel so others can see answers."))
	if FormRules.picked(picks, "runbook")[0] == "later":
		notes.append(t("Mina: '시간 날 때'는 안 와요. 지금 짧게라도 써 두면 다음 사람이 덜 묻게 돼요.", "Mina: 'When there's time' never comes. A short one now means fewer questions later."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	Game.state["flags"]["c03_owner"] = FormRules.picked(picks, "owner")[0]
	complete("own")
	if once("_reward"):
		Game.relate("daniel", {"work": 3, "agree": 2})
		Game.relate("mina", {"close": 1})
	if FormRules.picked(picks, "owner")[0] == "pair":
		Game.relate("sophie", {"close": 3, "agree": 2})
		say("sophie", t("화면 담당 좋아요! 제 이름도 운영 문서에 올라가네요.", "Screen owner, yes! My name's on the runbook too."))
	say("yuri", t("#preorder 채널로 다 옮겼어요. 화·목 오후에 모아서 물어볼게요.", "Moved everything to #preorder. I'll batch questions for Tue/Thu afternoons."))
	finish()
