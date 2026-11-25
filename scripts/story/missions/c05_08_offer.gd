extends "res://scripts/story/mission.gd"
## C05 M08 — another company's offer. If the Brightloop process reached terms, Jamie sends a real
## offer compared on work, support, product ownership, commute and pay (not pay alone). Stay, accept or
## hold; either way two unfinished pieces of work need named owners. Sets the employer for Chapter 6.

const PEOPLE := {
	"me": {"ko": "나", "en": "Me"}, "daniel": {"ko": "Daniel", "en": "Daniel"}, "taeseok": {"ko": "Taeseok", "en": "Taeseok"},
	"hana": {"ko": "Hana", "en": "Hana"}, "mina": {"ko": "Mina", "en": "Mina"}, "sophie": {"ko": "Sophie", "en": "Sophie"},
	"none": {"ko": "아직 정하지 않음", "en": "Not decided yet"},
}


func _init() -> void:
	id = "c05_08"
	chapter = 5
	day = 16
	issue = "NXR-068"
	title = t("다른 회사의 제안", "Another company's offer")
	objectives = [{"id": "handoff", "app": "docs", "text": t("Docs에서 미완료 업무 두 개의 인수자 정하기", "Name owners for two unfinished pieces of work in Docs")}]
	hints = [t("인수자를 '아직 정하지 않음'으로 두면 그 일은 아무도 안 하는 일이 돼요.", "Leave an owner as 'not decided' and that work becomes nobody's work.")]


func has_offer() -> bool:
	var arc = Story.arcs.arc("offer")
	return arc != null and arc.is_active() and arc.stage() >= 6


func leaving() -> bool:
	return String(Game.state["flags"].get("c05_offer", "")) == "accept"


func open_forms() -> Array:
	_build()
	return super.open_forms()


func submit_form(form_id: String, picks: Dictionary) -> Array:
	_build()
	return super.submit_form(form_id, picks)


## The offer comes first when there is one; the handoff opens after it (or right away without one).
func _build() -> void:
	forms_def = {}
	if has_offer() and not form_done("offer"):
		forms_def["offer"] = _offer_form()
	elif not has_offer() or form_done("offer"):
		forms_def["handoff"] = _handoff_form()
		if form_done("offer"):
			forms_def["offer"] = _offer_form()


func _offer_form() -> Dictionary:
	var arc = Story.arcs.arc("offer")
	var visited: bool = arc != null and String(arc.data().get("visit", "")) == "visit"
	var pay := 22 if String(Game.state["flags"].get("offer_priority", "")) == "pay" else 18
	var rows := [
		t("업무 · Brightloop: 결제 플랫폼 새로 구축 / NEXORA: ATLAS 2단계와 캠페인 운영", "Work · Brightloop: building a new payments platform / NEXORA: ATLAS stage 2 and campaign operations"),
		t("제품 책임 · Brightloop: 결제 흐름 전체 담당 / NEXORA: 환불·캠페인 범위", "Product ownership · Brightloop: the whole payment flow / NEXORA: refunds and campaigns"),
		t("지원 · Brightloop: 온보딩 멘토, 당직은 6주 뒤 합류 / NEXORA: Daniel·Hana와 익숙한 팀", "Support · Brightloop: an onboarding mentor, on-call after six weeks / NEXORA: a team you know, with Daniel and Hana")
			if visited else t("지원 · Brightloop: 사무실 방문을 건너뛰어 확인 못 함 / NEXORA: Daniel·Hana와 익숙한 팀", "Support · Brightloop: unknown, you skipped the office visit / NEXORA: a team you know, with Daniel and Hana"),
		t("통근 · Brightloop: 판교, 왕복 2시간 또는 이사(보증금 부담) / NEXORA: 지금 그대로", "Commute · Brightloop: Pangyo, two hours a day or a move (deposit costs) / NEXORA: unchanged")
			if visited else t("통근 · Brightloop: 판교 (이사 지원 여부 확인 못 함) / NEXORA: 지금 그대로", "Commute · Brightloop: Pangyo (relocation support unknown) / NEXORA: unchanged"),
		{"ko": "연봉 · Brightloop: 현재보다 +%d%% / NEXORA: 잔류 시 역할 확대 협의" % pay, "en": "Pay · Brightloop: +%d%% over now / NEXORA: a broader role if you stay" % pay},
	]
	var intro := {"ko": "Jamie가 보낸 공식 오퍼예요. 연봉만이 아니라 아래 다섯 줄을 같이 봐요.\n" + "\n".join(rows.map(func(r: Dictionary) -> String: return "· " + r["ko"])),
		"en": "Jamie's formal offer. Look at all five lines, not just pay.\n" + "\n".join(rows.map(func(r: Dictionary) -> String: return "· " + r["en"]))}
	return {
		"title": t("Brightloop 오퍼 비교", "Brightloop offer comparison"),
		"intro": intro,
		"submit": t("결정 보내기", "Send the decision"),
		"slots": [
			{"id": "decision", "label": t("결정", "Decision"), "options": [
				{"id": "stay", "text": t("남는다 — 역할 확대를 Alex·Daniel과 협의", "Stay — negotiate a broader role with Alex and Daniel")},
				{"id": "accept", "text": t("Brightloop로 옮긴다", "Move to Brightloop")},
				{"id": "hold", "text": t("보류한다 — 지금은 남고, 나중에 다시 이야기", "Hold — stay for now, talk again later")}]},
			{"id": "weigh", "label": t("가장 크게 본 것 (최대 2개)", "What weighed most (up to 2)"), "multi": true, "max": 2, "options": [
				{"id": "work", "text": t("업무", "The work")}, {"id": "product", "text": t("제품 책임", "Product ownership")},
				{"id": "support", "text": t("지원", "Support")}, {"id": "commute", "text": t("통근·이사", "Commute and moving")},
				{"id": "pay", "text": t("연봉", "Pay")}]},
		],
	}


func _handoff_form() -> Dictionary:
	var go := leaving()
	var people: Array = ["daniel", "taeseok", "hana", "sophie", "none"] if go else ["me", "sophie", "daniel", "hana", "none"]
	var items: Array
	if go:
		var l17 = Story.arcs.arc("legacy17")
		items = [["atlas", t("ATLAS 재처리 목록 담당", "Owner of the ATLAS retry list")],
			["l17", t("LEGACY-17 이관 규칙 마무리", "Finishing the LEGACY-17 migration rule") if l17 != null and l17.stage() >= 4 else t("다음 캠페인 운영표 초안", "The next campaign's rota draft")]]
	else:
		items = [["ratelimit", t("Mina의 일: 캠페인 요청 제한 설정", "Mina's work: campaign rate-limit settings")],
			["qa_check", t("Mina의 일: 캠페인 QA 체크리스트", "Mina's work: the campaign QA checklist")]]
	var slots: Array = []
	for it in items:
		slots.append({"id": it[0], "label": it[1], "inline": true, "options": people.map(func(p: String) -> Dictionary: return {"id": p, "text": PEOPLE[p]})})
	return {
		"title": t("인수인계 계획", "Handoff plan") ,
		"intro": t("떠나는 사람의 일은 이름이 붙어야 남아요. 두 업무의 인수자를 정해요.", "Work only survives a move when it has a name on it. Choose who takes over each.") if go
			else t("Mina가 다음 달 새 플랫폼팀으로 옮겨요. Mina가 맡던 두 가지를 누가 이어받을지 정해요.", "Mina moves to the new platform team next month. Decide who takes over her two pieces of work."),
		"submit": t("인수인계 확정", "Confirm the handoff"),
		"slots": slots,
	}


func begin() -> void:
	Game.set_time(15 * 60)
	Game.add_issue(issue, title, "decision", Game.L("나", "me"), "progress")
	if has_offer():
		say("recruiter", t("공식 오퍼예요. 비교표를 Docs에 정리해 뒀어요. 연봉은 비교하기 쉬우니까 나머지를 먼저 봐 주세요. 보류도 괜찮아요.",
			"Here's the formal offer. I put a comparison in Docs. Pay is easy to compare, so look at the rest first. Holding is fine too."), {"channel": "connectly"})
	else:
		Game.state["flags"]["employer"] = "nexora"
		_open_handoff()


## Reload safety: re-send the opening that leads to whichever form is open now.
func resume() -> void:
	if not is_done("handoff"):
		if has_offer() and not form_done("offer"):
			begin()
		else:
			_open_handoff()
		return
	super.resume()


func _open_handoff() -> void:
	if leaving():
		say("sophie", t("축하해요! 진짜로요. 그런데... 우리 같이 하던 거, 누가 이어받아요?", "Congratulations! Really. But... who takes over the things we were doing together?"))
		say("daniel", t("붙잡을 연봉을 드리진 않을게요. 대신 여기서 끝내고 싶은 일이랑, 거기서 시작하고 싶은 일을 따로 적어 봐요.",
			"I won't counter with salary. Instead, write down separately what you want to finish here and what you want to start there."))
	else:
		say("mina", t("저 다음 달부터 새 플랫폼팀으로 가요. 그래서... 제가 맡던 두 개, 누가 이어받을까요? Docs에 적어 뒀어요.",
			"I'm moving to the new platform team next month. So... who takes over my two things? It's in Docs."))


func judge_form(form_id: String, picks: Dictionary) -> Array:
	if form_id != "handoff":
		return []
	for slot in _handoff_form()["slots"]:
		if FormRules.picked(picks, slot["id"])[0] == "none":
			return [t("Daniel: 인수자가 없는 일은 아무도 안 하는 일이에요. 이름을 적어요. 나중에 바꿔도 돼요.", "Daniel: Work with no owner is work nobody does. Put a name on it; you can change it later.")]
	return []


func on_form_accepted(form_id: String, picks: Dictionary) -> void:
	if form_id == "offer":
		var decision: String = FormRules.picked(picks, "decision")[0]
		Game.state["flags"]["c05_offer"] = decision
		Game.state["flags"]["employer"] = "brightloop" if decision == "accept" else "nexora"
		Game.state["flags"]["c05_offer_weigh"] = FormRules.picked(picks, "weigh")
		var arc = Story.arcs.arc("offer")
		if arc != null:
			arc.data()["decision"] = decision
			arc.set_stage(7)
		match decision:
			"accept":
				say("recruiter", t("환영해요! 입사일은 다음 달 첫째 주로 잡을게요. 지금 팀에 인수인계할 시간은 충분히 드릴게요.", "Welcome aboard! Let's set the start for the first week of next month, with plenty of time to hand off."), {"channel": "connectly"})
			"stay":
				say("recruiter", t("아쉽지만 좋은 결정 같아요. 지금 팀에서 하고 싶은 일이 분명해 보여요. 연락은 계속해요.", "A shame for us, but it sounds like a good call. You clearly know what you want to do there. Let's keep in touch."), {"channel": "connectly"})
				say("alex", t("남아 줘서 고마워요. ATLAS 2단계 결정권을 같이 정리해 봐요. 말로만 말고 역할 문서로요.", "Thanks for staying. Let's write down your ownership of ATLAS stage 2, in a role document, not just words."))
				Game.relate("alex", {"agree": 3})
			"hold":
				say("recruiter", t("물론이죠. 반년쯤 뒤에 다시 이야기해요. 그때도 자리가 있으면 먼저 연락드릴게요.", "Of course. Let's talk again in six months or so. If there's a role then, I'll reach out first."), {"channel": "connectly"})
		Game.advance(30)
		await wait(1.0)
		if is_current():
			_open_handoff()
		return
	var handoff := {}
	for slot in _handoff_form()["slots"]:
		handoff[slot["id"]] = FormRules.picked(picks, slot["id"])[0]
	Game.state["flags"]["c05_handoff"] = handoff
	complete("handoff")
	Game.advance(30)
	if not leaving() and handoff.values().all(func(v: String) -> bool: return v == "me"):
		Game.state["flags"]["c05_overload"] = true
		say("daniel", t("둘 다 당신이네요. 할 수는 있겠지만, 다음 분기 계획에 그만큼 다른 걸 빼야 해요. 제가 기억해 둘게요.",
			"Both are yours. Doable, but next quarter's plan has to drop something to match. I'll remember that."))
	if once("_reward"):
		Game.relate("daniel", {"close": 2})
		Game.relate("mina", {"close": 2})
	doc_comment("handoff", "daniel", t("인수인계 확인했어요. 각자 첫 주에 30분씩 같이 앉는 걸로 일정 잡았어요.", "Handoff confirmed. I booked thirty minutes with each new owner in their first week."))
	await wait(1.0)
	if not is_current():
		return
	if leaving():
		say("sophie", t("이름 적어 둔 거 봤어요. 그럼 마지막 주엔 같이 점심 먹어요.", "I saw the names. Then let's have lunch together in your last week."))
	else:
		say("mina", t("고마워요. 이제 맘 편히 옮길 수 있겠어요.", "Thank you. Now I can move with a clear head."))
	Game.set_time(18 * 60)
	finish()
