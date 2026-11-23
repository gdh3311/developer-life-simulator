extends "res://scripts/story/mission.gd"
## C02 M07 — "merged" is not "solved". Limited rollout, accelerated observation, judging evidence,
## and recording who checks next. Driven from the Monitor app; rolling back is allowed.


func _init() -> void:
	id = "c02_07"
	chapter = 2
	day = 7
	issue = "NXR-027"
	title = t("고쳤다는 말의 조건", "When can we say it's fixed")
	objectives = [
		{"id": "announce", "text": t("Alex와 고객 안내 시점 정하기", "Decide with Alex when to tell the customer")},
		{"id": "scope", "text": t("Monitor에서 달빛상점에만 제한 적용", "Apply to Moonlight only in Monitor")},
		{"id": "observe", "text": t("관찰 구간 진행", "Run the observation window")},
		{"id": "evidence", "text": t("해결 근거가 되는 관찰 카드 고르기", "Pick the observation card that proves the fix")},
		{"id": "record", "text": t("확인 범위·다음 확인 시점·담당자 기록", "Record scope, next check time and owner")},
	]
	hints = [
		t("Monitor 앱 위쪽의 '배포와 관찰' 패널에서 진행해요. Wiki '배포와 관찰 기준'에 기준이 있어요.", "Use the 'Rollout & observation' panel at the top of Monitor. The Wiki page 'Rollout and observation' has the rules."),
		t("중복 0건만 보지 마세요. 그 시간에 주문과 재시도가 실제로 있었는지가 근거예요.", "Don't look at 'zero duplicates' alone. The evidence is that orders and retries actually happened in that window."),
	]


func rollout() -> Dictionary:
	if not Game.state["flags"].has("c02_rollout"):
		Game.state["flags"]["c02_rollout"] = {"scope": "", "observed": false, "evidence": "", "next": "", "owner": "", "rollbacks": 0}
	return Game.state["flags"]["c02_rollout"]


func begin() -> void:
	Game.set_time(13 * 60)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	monitor("api", "warn", "order_rollout")
	rollout()
	await wait(1.0)
	if not is_current():
		return
	if not is_done("announce") and not Game.pending_choice("c02_announce"):
		choice("alex", t("병합됐다고 들었어요! 지금 고객에게 연락하면, 오늘 저녁부터 안심하셔도 된다고 말해도 돼요?",
			"I heard it's merged! If I call the customer now, can I say they can relax from this evening?"),
			"c02_announce", [
				["staged", t("적용됐고 확인 중이라고 먼저 안내하죠. 종료는 오늘 관찰 뒤에요.", "Say it's applied and being checked. We close it after today's observation.")],
				["after", t("정상 주문과 재시도 표본을 확인한 뒤 완료라고 보내겠습니다.", "I'll confirm normal orders and retry samples, then we send 'done'.")],
				["customer", t("우선 고객이 한 번 써 보고 알려 주면 어떨까요?", "How about the customer tries it and lets us know?")]])


## --- Actions called from the Monitor panel --------------------------------------------

func apply(scope: String) -> void:
	if not is_current():
		return
	if scope == "all":
		Game.relate("daniel", {"agree": -2})
		say("daniel", t("검증한 범위보다 넓어요. 문제를 신고한 달빛상점에서 먼저 확인합시다. 전체 적용은 관찰 뒤에 정해요.",
			"That's wider than what we verified. Check with Moonlight, who reported it, first. We decide on everyone after observing."))
		return
	rollout()["scope"] = "moonlight"
	Game.advance(10)
	complete("scope")
	Game.emit_event("rollout", {"step": "scope"})


func observe() -> void:
	if not is_current() or rollout()["scope"] != "moonlight":
		return
	rollout()["observed"] = true
	Game.advance(30)
	complete("observe")
	Game.emit_event("rollout", {"step": "observe"})


func choose_evidence(card: String) -> void:
	if not is_current() or not rollout()["observed"]:
		return
	if card == "quiet":
		Game.emit_event("rollout", {"step": "quiet"})
		say("mina", t("그 카드는 중복이 0건인데 주문도 0건이에요. 그 시간에 주문이 없었다면 확인한 게 없어요.",
			"That card shows zero duplicates, but also zero orders. If nobody ordered, we haven't checked anything."))
		return
	rollout()["evidence"] = "traffic"
	complete("evidence")
	Game.emit_event("rollout", {"step": "evidence"})


func record(next_check: String, owner: String) -> void:
	if not is_current() or rollout()["evidence"] != "traffic" or next_check == "" or owner == "":
		return
	rollout()["next"] = next_check
	rollout()["owner"] = owner
	Game.advance(5)
	complete("record")
	Game.emit_event("rollout", {"step": "record"})
	_check_done()


func roll_back() -> void:
	if not is_current() or rollout()["scope"] == "":
		return
	var r := rollout()
	r["scope"] = ""
	r["observed"] = false
	r["evidence"] = ""
	r["rollbacks"] = int(r["rollbacks"]) + 1
	for o in ["scope", "observe", "evidence"]:
		st()["obj"][o] = false
	story.objectives_changed.emit()
	Game.emit_event("rollout", {"step": "rollback"})
	if once("_rollback_note"):
		say("daniel", t("되돌리는 건 실패가 아니에요. 기준에 못 미치면 제한을 유지하거나 되돌리고 다시 보면 돼요.",
			"Rolling back isn't failure. If we don't meet the bar, keep the limit or roll back and look again."))


func _check_done() -> void:
	if not is_current() or not all_done() or data().get("finished", false):
		return
	data()["finished"] = true
	monitor("api", "ok", "normal")
	if once("_reward"):
		Game.relate("alex", {"work": 4})
		Game.relate("mina", {"work": 2})
	await wait(1.5)
	if not is_current():
		return
	say("sophie", t("오늘 주문 버튼 누른 사람들은 우리가 이거 고친 걸 모르겠죠?", "The people who clicked 'order' today won't even know we fixed this, right?"), {"channel": "general"})
	await wait(1.5)
	if not is_current():
		return
	say("mina", t("그게 잘된 거죠.", "That's how you know it worked."), {"channel": "general"})
	finish()


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "choice" and d["key"] == "c02_announce":
		match d["option"]:
			"staged":
				Game.relate("alex", {"agree": 2})
				say("alex", t("좋아요. '적용됐고 확인 중'으로 먼저 보내고, 종료 안내는 관찰 뒤에 할게요.", "Good. I'll send 'applied and being checked' now, and the closing note after observing."))
			"after":
				say("alex", t("알겠어요. 대신 중간에 진행 상황은 한 번 알려 주세요.", "Okay. Just give me one progress update along the way."))
			"customer":
				say("yuri", t("사용해 보시라고 할 수는 있어요. 다만 우리 쪽 확인도 같이 해야 해요. 고객이 테스트 담당자는 아니니까요.",
					"We can ask them to try it. But we have to check on our side too. The customer isn't our tester."))
		complete("announce")
		_check_done()
