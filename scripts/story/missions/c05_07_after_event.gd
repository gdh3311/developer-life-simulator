extends "res://scripts/story/mission.gd"
## C05 M07 — the work after a good event. Close the reconciliation list, then write the end report:
## a revenue graph alone is not a result. The numbers come from last night's real rush.


func _init() -> void:
	id = "c05_07"
	chapter = 5
	day = 16
	issue = "NXR-067"
	title = t("잘된 행사 뒤의 일", "The work after a good event")
	objectives = [
		{"id": "recon", "text": t("조정 목록 처리 방법 정하기", "Decide how the reconciliation list is handled")},
		{"id": "report", "app": "docs", "text": t("Docs에서 행사 종료 보고서 제출", "Submit the campaign close report in Docs")},
	]
	hints = [
		t("매출 그래프는 Alex가 이미 올렸어요. 보고서는 그래프가 말하지 않는 것을 적는 문서예요.", "Alex already posted the revenue graph. The report is for what the graph doesn't say."),
		t("조정 목록과 당직 시간이 빠지면 다음 행사도 똑같이 준비하게 돼요.", "Leave out the reconciliation list and the on-call hours, and the next campaign gets prepared the same way."),
	]


func rush() -> Dictionary:
	var r = Game.state["flags"].get("c05_rush", {})
	return r if r is Dictionary else {}


func open_forms() -> Array:
	_build()
	return super.open_forms()


func submit_form(form_id: String, picks: Dictionary) -> Array:
	_build()
	return super.submit_form(form_id, picks)


## The report's options carry last night's real numbers.
func _build() -> void:
	var r := rush()
	var recon := (r.get("reconcile", []) as Array).size()
	var problems := int(r.get("oversold", 0)) + int(r.get("duplicateCharges", 0)) + int(r.get("wrongPrice", 0))
	var rota: Dictionary = Game.state["flags"].get("c05_rota", {})
	var extend := String(Game.state["flags"].get("c05_extend", "decline"))
	var safety: Dictionary
	if problems == 0:
		safety = t("초과 판매·중복 청구·틀린 가격 0건 — 리허설 시나리오와 테스트로 예방", "Zero oversells, double charges and wrong prices — prevented by the rehearsal scenario and tests")
	else:
		safety = {"ko": "보정 대상 %d건 (초과 판매 %d · 중복 청구 %d · 틀린 가격 %d)과 처리 경로" % [problems, int(r.get("oversold", 0)), int(r.get("duplicateCharges", 0)), int(r.get("wrongPrice", 0))],
			"en": "%d to correct (oversold %d · double charges %d · wrong prices %d) and how they're handled" % [problems, int(r.get("oversold", 0)), int(r.get("duplicateCharges", 0)), int(r.get("wrongPrice", 0))]}
	var hours := 0
	for w in ["eve", "night", "morning"]:
		if rota.get(w, "") == "me":
			hours += {"eve": 2, "night": 10, "morning": 2}[w]
	forms_def = {"report": {
		"title": t("봄 캠페인 종료 보고서", "Spring campaign close report"),
		"intro": t("다음 행사를 준비할 사람이 읽을 문서예요. 넣을 항목을 고르세요 (최대 4개).", "This is for whoever prepares the next campaign. Pick what goes in (up to four)."),
		"submit": t("팀에 공유", "Share with the team"),
		"slots": [{"id": "include", "label": t("보고서 항목", "Report sections"), "multi": true, "max": 4, "options": [
			{"id": "revenue", "text": {"ko": "매출 그래프 (누적 %s)" % Game.won(int(r.get("revenue", 0))), "en": "Revenue graph (total %s)" % Game.won(int(r.get("revenue", 0)))}},
			{"id": "safety", "text": safety},
			{"id": "recon", "text": {"ko": "조정 목록 %d건과 처리 담당" % recon, "en": "Reconciliation list: %d entries and who handles them" % recon}},
			{"id": "fatigue", "text": {"ko": "당직 시간과 피로 (내 당직 %d시간)" % hours, "en": "On-call hours and fatigue (my on-call: %dh)" % hours}},
			{"id": "moonlight", "text": {"accept": t("달빛상점 연장 1시간 결과", "Moonlight's extra hour"), "reduce": t("달빛상점 30분 축소 연장 결과", "Moonlight's shortened 30-minute extension"),
				"decline": t("달빛상점 연장 거절 이유와 다음 요청 기한", "Why Moonlight's extension was declined, and the deadline for next time")}[extend]},
			{"id": "praise", "text": t("팀 감사 인사", "Thanks to the team")}]}],
	}}


func begin() -> void:
	Game.set_time(9 * 60 + 30)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	say("system", t("열 번째 달 · 수요일", "Month ten · Wednesday"), {"channel": "general", "silent": true})
	var recon := (rush().get("reconcile", []) as Array).size()
	say("hana", {"ko": "좋은 아침이에요. 조정 목록에 %d건 있어요. 전부 고객이 취소한 뒤 도착한 결제 성공이에요. 어떻게 처리할까요?" % recon,
		"en": "Morning. The reconciliation list has %d entries, all payment successes that arrived after the customer cancelled. How do we handle them?" % recon})
	choice("hana", t("조정 목록 처리", "Reconciliation list"), "c05_recon", [
		["refund", t("고객별로 확인하고 환불한 뒤 고객 성공팀에 안내 문구를 넘겨요.", "Check each customer, refund, and hand Customer Success a notice.")],
		["auto", t("전부 자동 환불 스크립트로 한 번에 돌려요.", "Run an auto-refund script over all of them at once.")],
		["later", t("다음 주 정산 때 같이 봐요.", "Look at them with next week's settlement.")]])
	if Game.state["flags"].get("c05_seojin_followup", false):
		await wait(1.0)
		if is_current():
			say("seojin", t("어제는 아쉬웠지만 이해했어요. 다음 행사 때 연장이 필요하면 언제까지 말씀드려야 준비가 되나요?",
				"Yesterday was disappointing, but I understand. If we need extra hours next time, how far ahead should I ask so you can prepare?"), {"channel": "connectly"})
			say("yuri", t("서진 사장님 질문은 제가 '2주 전, 운영표와 함께'로 답해 둘게요. 보고서에도 그 기한을 적어 주세요.",
				"I'll answer Seojin with 'two weeks ahead, together with the rota'. Put that deadline in the report too."))


func resume() -> void:
	if not is_done("recon") and not Game.pending_choice("c05_recon"):
		begin()
		return
	super.resume()


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice" or d.get("key", "") != "c05_recon" or is_done("recon"):
		return
	var option := String(d["option"])
	Game.state["flags"]["c05_recon"] = option
	match option:
		"refund":
			Game.relate("daniel", {"agree": 2})
			say("yuri", t("안내 문구 받았어요. '취소하신 주문에 결제가 늦게 확인되어 환불했습니다'로 보낼게요.", "Got the notice. I'll send 'A payment for your cancelled order was confirmed late; it has been refunded.'"))
		"auto":
			say("daniel", t("스크립트를 돌리기 전에 한 건만 손으로 확인해요. 같은 고객이 다시 주문했을 수도 있어요.", "Check one by hand before running a script. The same customer may have ordered again."))
			say("hana", t("확인해 보니 한 건은 같은 고객이 재주문한 거였어요. 그 건은 빼고 돌릴게요.", "Checked: one was the same customer reordering. I'll run it without that one."))
		"later":
			Game.relate("daniel", {"agree": -2})
			say("hana", t("고객은 일주일 동안 취소한 주문에 돈이 빠진 채로 있어요. 오늘 처리하는 걸로 바꿀게요.", "Then customers sit a week with money taken for a cancelled order. I'll switch it to today."))
	complete("recon")
	Game.advance(40)


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var inc := FormRules.picked(picks, "include")
	var notes: Array = []
	if not "recon" in inc:
		notes.append(t("Hana: 조정 목록이 빠지면 다음 행사 때 같은 일이 또 '예상 밖'이 돼요.", "Hana: Without the reconciliation list, next campaign the same thing is 'unexpected' again."))
	if not "fatigue" in inc:
		notes.append(t("Mina: 누가 몇 시간 깨어 있었는지가 빠졌어요. 그게 다음 운영표의 근거예요.", "Mina: Who was awake for how long is missing. That's the basis for the next rota."))
	if not "safety" in inc:
		notes.append(t("Daniel: 초과 판매와 중복 청구 숫자가 없어요. 0건이라도 적어야 다음 사람이 무엇을 지켜야 하는지 알아요.", "Daniel: The oversell and double-charge numbers are missing. Even zero belongs in it, so the next person knows what to protect."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	Game.state["flags"]["c05_report"] = FormRules.picked(picks, "include")
	complete("report")
	Game.advance(30)
	if once("_reward"):
		Game.relate("mina", {"work": 2})
		Game.relate("alex", {"work": 2})
	say("alex", t("그래프는 제가 올렸고, 보고서는 다음 행사의 출발점이 됐네요. 영업팀도 '세 배' 대신 분당 기록을 쓰겠대요.",
		"I posted the graph; your report became the starting point for the next campaign. Sales will use per-minute records instead of 'three times' from now on."))
	doc_comment("report", "hana", t("SRE: 다음 행사 운영표 초안은 이 보고서의 당직 시간 기준으로 잡겠습니다.", "SRE: the next campaign's rota draft will start from the on-call hours in this report."))
	if Game.state["flags"].get("c05_seojin_followup", false):
		doc_comment("report", "yuri", t("고객 성공: 연장 요청은 2주 전, 운영표와 함께 — 달빛상점에 안내 완료.", "Customer Success: extension requests two weeks ahead with the rota — Moonlight informed."))
	finish()
