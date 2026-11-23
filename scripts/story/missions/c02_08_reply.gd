extends "res://scripts/story/mission.gd"
## C02 M08 — write the customer reply without jargon or overclaiming, then the quiet evening.

## Each slot: options [id, text, ok, Yuri's note when not ok].
const SLOTS := {
	"change": {"label": {"ko": "무엇이 바뀌었나", "en": "What changed"}, "options": [
		["plain", {"ko": "주문을 처리하는 동안 같은 요청이 다시 전달되면 새 주문이 만들어지던 부분을 수정했습니다. 이제 같은 구매 시도는 기존 주문으로 연결됩니다.", "en": "We fixed the part where a request sent again during processing created a new order. The same purchase attempt now links to the existing order."}, true, {}],
		["jargon", {"ko": "createOrder에 claim/complete 기반 멱등성 선점 로직을 적용해 레이스 컨디션을 제거했습니다.", "en": "We applied claim/complete-based idempotent locking to createOrder, removing the race condition."}, false,
			{"ko": "고객이 코드 용어를 알 필요는 없어요. 고객 입장에서 무엇이 달라졌는지만 적어 주세요.", "en": "The customer doesn't need our code terms. Just say what changed from their side."}],
		["over", {"ko": "주문 시스템의 오류를 모두 완전히 해결했습니다.", "en": "We have completely fixed every error in the order system."}, false,
			{"ko": "확인한 범위보다 크게 말하면 다음 문의 때 신뢰를 잃어요.", "en": "Claiming more than we verified costs trust at the next inquiry."}],
	]},
	"verified": {"label": {"ko": "어디까지 확인했나", "en": "What we verified"}, "options": [
		["scoped", {"ko": "현재 달빛상점에 적용했고, 정상 주문과 재시도 결과를 확인했습니다.", "en": "It is applied to Moonlight now, and we checked normal orders and retries."}, true, {}],
		["tests", {"ko": "테스트를 모두 통과했습니다.", "en": "All tests passed."}, false,
			{"ko": "고객에게는 테스트보다 실제로 무엇을 확인했는지가 중요해요.", "en": "For the customer, what we actually checked matters more than tests."}],
		["all", {"ko": "모든 상점에 배포를 마쳤습니다.", "en": "We rolled it out to every shop."}, false,
			{"ko": "아직 달빛상점에만 적용했잖아요. 사실과 다르면 안 돼요.", "en": "It's only applied to Moonlight so far. It has to be accurate."}],
	]},
	"existing": {"label": {"ko": "이미 생긴 중복 주문", "en": "Duplicates that already exist"}, "options": [
		["follow", {"ko": "이미 중복으로 생성된 주문은 별도로 확인하고 있으며, 담당자가 처리 결과를 안내드리겠습니다.", "en": "We are reviewing the orders that were already duplicated, and the owner will update you on the result."}, true, {}],
		["delete", {"ko": "중복으로 생긴 주문은 직접 삭제해 주세요.", "en": "Please delete the duplicated orders yourself."}, false,
			{"ko": "삭제를 고객에게 맡기면 안 돼요. 결제가 엮여 있을 수 있어요.", "en": "We can't hand deletion to the customer. Payments may be involved."}],
		["omit", {"ko": "(언급하지 않음)", "en": "(not mentioned)"}, false,
			{"ko": "어제 실제로 중복 주문이 있었어요. 남아 있는 조치를 적어야 해요.", "en": "There really were duplicates yesterday. We need to state what's still being done."}],
	]},
	"contact": {"label": {"ko": "다시 문제가 보이면", "en": "If it happens again"}, "options": [
		["support", {"ko": "같은 증상이 다시 보이면 주문 번호와 시각을 이 메일로 알려 주세요.", "en": "If you see the same symptom again, reply to this email with the order number and time."}, true, {}],
		["devteam", {"ko": "문제가 계속되면 개발팀에 직접 연락해 주세요.", "en": "If the problem continues, please contact the dev team directly."}, false,
			{"ko": "고객 창구는 저예요. 개발팀 직통은 열어 두지 않아요.", "en": "I'm the customer contact. We don't open a direct line to the dev team."}],
	]},
}


func _init() -> void:
	id = "c02_08"
	chapter = 2
	day = 7
	issue = "NXR-028"
	title = t("저녁 여섯 시의 답장", "The 6 PM reply")
	objectives = [
		{"id": "sent", "text": t("Request Lab '고객 답장'에서 답장 초안 보내기", "Send the reply draft from Request Lab > Customer reply")},
		{"id": "retro", "text": t("Daniel과 짧은 회고", "A short retro with Daniel")},
		{"id": "wrap", "text": t("오늘 일 마무리하기", "Wrap up the day")},
	]
	hints = [
		t("네 칸을 모두 채워요: 무엇이 바뀌었나, 어디까지 확인했나, 이미 생긴 중복, 다시 문제가 보이면. 고객의 말로, 확인한 만큼만.", "Fill all four slots: what changed, what we verified, existing duplicates, and what to do if it recurs. In the customer's words, no more than we verified."),
	]


func reply_state() -> Dictionary:
	if not Game.state["flags"].has("c02_reply"):
		Game.state["flags"]["c02_reply"] = {"sent": false, "attempts": 0}
	return Game.state["flags"]["c02_reply"]


func begin() -> void:
	Game.set_time(17 * 60 + 20)
	Game.add_issue(issue, title, "support", Game.L("나", "me"), "progress")
	reply_state()
	await wait(1.0)
	if not is_current():
		return
	say("yuri", t("고객 답장 초안 부탁해도 될까요? 바뀐 것, 고객이 할 일, 남은 조치, 다시 문의하는 방법이 들어가면 돼요. Request Lab의 '고객 답장' 탭에 틀을 만들어 뒀어요.",
		"Could you draft the customer reply? It needs what changed, what the customer should do, what's still in progress, and how to reach us. I set up a template in Request Lab > Customer reply."))


## Called by the reply composer. picks: { slot: option_id }. Returns the notes for rejected slots.
func submit(picks: Dictionary) -> Array:
	if not is_current() or reply_state()["sent"]:
		return []
	var notes: Array = []
	for slot in SLOTS:
		var chosen := String(picks.get(slot, ""))
		var found := false
		for option in SLOTS[slot]["options"]:
			if option[0] == chosen:
				found = true
				if not option[2]:
					notes.append(option[3])
		if not found:
			notes.append({"ko": "'%s' 칸이 비어 있어요." % SLOTS[slot]["label"]["ko"], "en": "The '%s' slot is empty." % SLOTS[slot]["label"]["en"]})
	reply_state()["attempts"] = int(reply_state()["attempts"]) + 1
	if not notes.is_empty():
		say("yuri", {"ko": "\n".join(notes.map(func(n: Dictionary) -> String: return "• " + n["ko"])), "en": "\n".join(notes.map(func(n: Dictionary) -> String: return "• " + n["en"]))})
		return notes
	reply_state()["sent"] = true
	reply_state()["picks"] = picks.duplicate()
	Game.advance(15)
	Game.emit_event("customer_reply", {"attempts": reply_state()["attempts"]})
	_after_sent()
	return []


func _after_sent() -> void:
	complete("sent")
	if once("_reply_reward"):
		Game.relate("alex", {"work": 4 if int(reply_state()["attempts"]) == 1 else 2})
	say("yuri", t("좋아요, 이대로 보냈어요. 내부 용어 없이, 확인한 만큼만 적혀 있어서 좋네요.", "Great, sent as is. No internal jargon and no more than we verified. Nice."))
	await wait(3.0)
	if not is_current():
		return
	Game.set_time(18 * 60 + 5)
	say("yuri", t("달빛상점에서 답장이 왔어요.\n\n“오늘은 중복이 안 보이네요. 원래 여섯 시쯤 주문 목록을 한 번씩 다 대조했거든요. 오늘은 그냥 밥 먹으러 갑니다. 감사합니다.”",
		"Moonlight replied.\n\n“No duplicates today. I used to cross-check the whole order list around six. Today I'm just going to dinner. Thank you.”"))
	await wait(2.5)
	if not is_current():
		return
	if not Game.pending_choice("c02_retro") and not is_done("retro"):
		choice("daniel", t("이번 일, 코드 바꾼 시간만 적으면 얼마나 걸렸어요?", "This task. If you count only the time spent changing code, how long did it take?"),
			"c02_retro", [
				["short", t("생각보다 짧았어요. 그 전에 확인할 게 더 많았네요.", "Shorter than I thought. There was more to check before it.")],
				["rules", t("같이 정한 규칙이 없었으면 다시 고쳤을 것 같아요.", "Without the rules we agreed on, I'd have fixed it twice.")]])


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "choice":
		return
	match d["key"]:
		"c02_retro":
			Game.relate("daniel", {"agree": 3, "close": 2})
			say("daniel", t("다음 일은 그걸 조금 더 빨리 할 수 있겠죠. 코드를 더 빨리 치는 것하고는 다르게요.", "Next time you'll do that part a bit faster. That's different from typing code faster."))
			say("mina", t("테스트 예시는 지원 쪽에서도 볼 수 있게 해 둘게요. 다음 문의는 좀 짧아지겠네요.", "I'll make the test examples visible to support too. The next inquiry should be shorter."), {"channel": "general"})
			say("sophie", t("제 화면 PR도 닫혔어요. 오늘은 정말 처리 완료!", "My screen PR is closed too. Today is officially done!"), {"channel": "general"})
			complete("retro")
			await wait(2.0)
			if not is_current():
				return
			say("daniel", t("아, Taeseok이 감사 로그를 보냈는데, 예전 주문 중 결제 쪽 번호랑 주문 쪽 번호가 다른 게 좀 있대요. 지금 금액은 맞고요. Wiki에 LEGACY-17이 있을 거예요. 오늘 해결할 일은 아니에요. 조사할 때 저도 같이 볼게요.",
				"Oh, Taeseok sent an audit log: some old orders have different payment-side and order-side IDs. The amounts are fine now. There should be a LEGACY-17 page in the Wiki. Not today's problem. I'll look at it with you when we investigate."))
			Game.add_issue("LEGACY-17", Game.LL("예전 주문의 결제·주문 번호 불일치 조사", "Investigate mismatched payment/order IDs on old orders"), "investigation", "Daniel", "todo")
			await wait(2.0)
			if not is_current():
				return
			choice("yuri", t("고객 답장 고마웠어요. 오늘 일, 어떻게 마무리할래요?", "Thanks for the reply. How do you want to wrap up today?"), "c02_wrap", [
				["thank", t("고객에게 짧게 감사 인사를 보낸다", "Send the customer a short thank-you")],
				["share", t("팀 채널에 동료들 공로를 정리해 공유한다", "Share a note crediting the team in the channel")],
				["note", t("오늘 배운 것을 내 노트에 기록해 둔다", "Write down what I learned today")]])
		"c02_wrap":
			match d["option"]:
				"thank":
					say("yuri", t("보낼게요. 고객이 좋아하실 거예요.", "I'll send it. They'll appreciate it."))
				"share":
					Game.relate("mina", {"close": 2})
					Game.relate("sophie", {"close": 2})
					say("sophie", t("이름 나오니까 좀 부끄럽네요. 고마워요!", "Seeing my name there is a bit embarrassing. Thank you!"), {"channel": "general"})
				"note":
					Game.state["flags"]["c02_notebook"] = true
			Game.state["flags"]["c02_wrap"] = d["option"]
			complete("wrap")
			finish()
