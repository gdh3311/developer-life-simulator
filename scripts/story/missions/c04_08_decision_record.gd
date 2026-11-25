extends "res://scripts/story/mission.gd"
## C04 M08 — the first decision record. Present ATLAS stage 1 to other teams; when you don't know,
## leave an owner and a date. Ends with another team commenting on your document.

const QUESTIONS := [
	["q_finance", "taeseok", {"ko": "정산팀: 재처리 목록이 쌓이면 정산 마감은 어떻게 하죠?", "en": "Finance: what happens to the close when the retry list grows?"},
		[["know", {"ko": "매일 비우는 게 시범 기준이고, 남으면 그날 마감 전에 담당자가 확인합니다.", "en": "Emptying it daily is the pilot bar; anything left is checked by the owner before that day's close."}],
		["owner", {"ko": "지금은 답할 수 없어요. 금요일까지 Taeseok과 마감 절차를 정해 답하겠습니다.", "en": "I can't answer yet. I'll settle the close procedure with Taeseok and reply by Friday."}],
		["bluff", {"ko": "재처리 목록은 거의 안 쌓일 거예요.", "en": "The retry list will barely grow."}]]],
	["q_support", "yuri", {"ko": "지원팀: 첫 계약 판매자 환불이 바뀌면 고객에게 언제 알리죠?", "en": "Support: if launch-contract refunds change, when do we tell customers?"},
		[["know", {"ko": "계약이 끝나는 3월 전에는 바뀌지 않아요. 특성 테스트로 고정해 뒀습니다.", "en": "Nothing changes before the contract ends in March. Characterization tests pin it."}],
		["owner", {"ko": "Alex와 계약 일정을 확인해 다음 주 화요일까지 공지 초안을 드릴게요.", "en": "I'll confirm the contract dates with Alex and send a notice draft by next Tuesday."}],
		["bluff", {"ko": "고객은 차이를 못 느낄 거예요.", "en": "Customers won't notice."}]]],
	["q_platform", "daniel", {"ko": "플랫폼팀: 원장 저장소 비용은 누가 내죠?", "en": "Platform: who pays for the ledger storage?"},
		[["owner", {"ko": "아직 정하지 않았어요. 이번 주 안에 Alex가 플랫폼팀과 정하도록 남겨 두겠습니다.", "en": "Not decided. I'll note it for Alex to settle with Platform this week."}],
		["bluff", {"ko": "얼마 안 들 거예요.", "en": "It won't cost much."}],
		["deflect", {"ko": "그건 제 업무가 아니에요.", "en": "That's not my job."}]]],
]


func _init() -> void:
	id = "c04_08"
	chapter = 4
	day = 13
	issue = "NXR-058"
	title = t("처음 쓰는 결정 기록", "The first decision record")
	objectives = [
		{"id": "answered", "text": t("다른 팀 질문 세 개에 답하기", "Answer three questions from other teams")},
		{"id": "approved", "text": t("ATLAS 1단계 제한 시범 승인", "Get the limited ATLAS stage 1 pilot approved")},
	]
	hints = [t("모르는 건 모른다고 하고, 확인할 담당자와 기한을 남기면 돼요. 그럴듯한 추측이 가장 비싸요.", "Say what you don't know and leave an owner and a date. A plausible guess is the most expensive answer.")]


func begin() -> void:
	Game.set_time(16 * 60 + 30)
	Game.add_issue(issue, title, "decision", Game.L("나", "me"), "progress")
	say("alex", t("ATLAS 결정 기록, 다른 팀들 앞에서 설명할 시간이에요. 저도 옆에 있을게요. 질문이 올 거예요.", "Time to present the ATLAS decision record to the other teams. I'll be next to you. Questions are coming."))
	await wait(1.0)
	if is_current():
		_ask_next()


## Reload safety: re-ask the current question or finish the wrap-up that was in flight.
func resume() -> void:
	var asked := int(data().get("asked", 0))
	if asked >= QUESTIONS.size():
		_wrap()
		return
	if not Game.pending_choice(QUESTIONS[asked][0]):
		_ask_next()
		return
	super.resume()


func _ask_next() -> void:
	var i := int(data().get("asked", 0))
	if i >= QUESTIONS.size():
		_wrap()
		return
	var q: Array = QUESTIONS[i]
	if Game.pending_choice(q[0]):
		return
	choice(q[1], q[2], q[0], q[3])


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	var key := String(d.get("key", ""))
	var idx := -1
	for i in QUESTIONS.size():
		if QUESTIONS[i][0] == key:
			idx = i
	if idx < 0 or idx != int(data().get("asked", 0)):
		return
	var answers: Dictionary = data().get("answers", {})
	answers[key] = d["option"]
	data()["answers"] = answers
	data()["asked"] = idx + 1
	match String(d["option"]):
		"owner":
			Game.relate("alex", {"agree": 2})
			var open: Array = Game.state["flags"].get("c04_open_questions", [])
			open.append(key)
			Game.state["flags"]["c04_open_questions"] = open
		"bluff":
			Game.relate("daniel", {"agree": -2})
			say("daniel", t("(작게) 그거 확인한 거예요? 아니면 담당과 기한을 남기는 게 나아요.", "(quietly) Did you verify that? If not, leave an owner and a date instead."))
		"deflect":
			Game.relate("alex", {"work": -3})
			say("alex", t("결정 기록에 우리 이름이 있으면 질문도 우리 거예요. 담당을 정하는 것까지가 일이에요.", "If our names are on the record, the questions are ours. Assigning an owner is part of the job."))
	_ask_next()


## Every step here is safe to repeat (say() dedupes, rewards use once()), so a reload can rerun it.
func _wrap() -> void:
	if not is_current():
		return
	complete("answered")
	var answers: Dictionary = data().get("answers", {})
	var honest := answers.values().filter(func(a) -> bool: return a in ["know", "owner"]).size()
	await wait(1.5)
	if not is_current():
		return
	if String(Game.state["flags"].get("c04_scope", "phased")) == "status_quo":
		say("alex", t("승인됐어요. 현상 유지와 매주 수동 대조, 3월 계약 만료 전 재검토. 남은 질문 목록도 결정 기록에 붙었어요.",
			"Approved: keep the current system with weekly manual reconciliation, and review before the March contract expiry. The open questions are attached to the record."))
	else:
		say("alex", t("승인됐어요. ATLAS 1단계, 환불부터 제한 시범. 남은 질문 목록도 결정 기록에 붙었어요.", "Approved. ATLAS stage 1: a limited pilot, refunds first. The open questions are attached to the record."))
	Game.state["flags"]["c04_approved"] = true
	Game.state["flags"]["c04_honest_answers"] = honest
	complete("approved")
	if once("_reward"):
		Game.relate("alex", {"work": 4})
		Game.relate("daniel", {"tech": 2})
	await wait(2.0)
	if not is_current():
		return
	Game.set_time(18 * 60)
	doc_comment("decision", "taeseok", t("정산팀: 재처리 목록 담당자 이름이 여기 있어서 좋네요. 3월 계약 만료 일정도 이 문서에 같이 적어 주실 수 있나요?",
		"Finance: glad the retry-list owner is named here. Could you add the March contract expiry to this doc too?"), "c04_05")
	var open: Array = Game.state["flags"].get("c04_open_questions", [])
	if not open.is_empty():
		doc_comment("decision", "alex", {"ko": "남은 질문 %d개: 담당과 기한을 붙여 이 문서에 연결했어요." % open.size(), "en": "%d open questions: linked here with owners and dates." % open.size()}, "c04_05")
	say("taeseok", t("📄 'ATLAS 1단계 결정 기록'에 정산팀 댓글: “재처리 목록 담당자 이름이 여기 있어서 좋네요. 3월 계약 만료 일정도 이 문서에 같이 적어 주실 수 있나요?”",
		"📄 Finance commented on 'ATLAS stage 1 decision record': “Glad the retry-list owner is named here. Could you add the March contract expiry to this doc too?”"), {"channel": "general"})
	await wait(1.5)
	if is_current():
		say("daniel", t("다른 팀이 당신 문서에 질문을 다네요. 이제 당신 PR 바깥의 일에도 이름이 남는 거예요.", "Another team is commenting on your document. Your name is on work beyond your own PRs now."))
		finish()
