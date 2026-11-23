extends "res://scripts/story/mission.gd"


func _init() -> void:
	id = "c02_01"
	chapter = 2
	day = 5
	issue = "NXR-021"
	title = t("월요일의 빈칸", "Monday's missing details")
	objectives = [
		{"id": "ticket", "app": "lab", "text": t("Request Lab에서 달빛상점 지원 티켓 읽기", "Read Moonlight's ticket in Request Lab")},
		{"id": "evidence", "app": "lab", "text": t("사내 요청 기록으로 확인된 사실 찾기", "Inspect the internal request records")},
		{"id": "plan", "app": "lab", "text": t("같은 요청과 재전송 조건을 재현 계획으로 기록", "Record a plan comparing the same request and its resends")},
	]
	hints = [t("Request Lab의 '지원 티켓'에서 기록을 확인하세요. 같은 구매 시도였는지와 전송 횟수를 비교하는 계획을 세울 수 있어요.", "Open Support ticket in Request Lab. Inspect the records and plan to compare one purchase attempt and its resend count.")]


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	monitor("api", "warn", "order_duplicates")
	say("system", t("두 번째 달 · 첫 고객 담당 업무입니다.", "Month two · Your first customer assignment."), {"channel": "general", "silent": true})
	say("alex", t("달빛상점 주문 이슈를 처음부터 끝까지 맡아 봐 주세요. 혼자 다 하라는 뜻은 아니에요. 고객 답장은 제가 창구를 맞출게요.", "Please take Moonlight's order issue from first report to follow-up. You won't do it alone; I'll coordinate the customer replies."))
	if int(Game.state["rank"]) >= 1:
		say("alex", t("정규직 전환 뒤 첫 고객 담당이네요. 검토는 Daniel과 함께 진행해 주세요.", "Your first customer assignment since becoming full-time. Work through the review with Daniel."))
	say("sophie", t("이제 보드 맨 위에 이름이 있네요! Request Lab에 지원 티켓을 옮겨 뒀어요. 먼저 아는 것과 모르는 걸 나눠 봐요.", "Your name is at the top of the board! The ticket is in Request Lab. Start with what we know and what we still need to learn."))
	await wait(2.0)
	if not is_current():
		return
	if not Game.state["flags"].has("c02_ask") and not Game.pending_choice("c02_ask"):
		choice("yuri", t("안녕하세요, 고객 성공팀 Yuri예요. 달빛상점 창구를 맡고 있어요. 고객에게 다시 물어볼 수 있는데, 바쁜 시간에는 답이 늦을 거예요. 우리가 볼 수 있는 것부터 정리해 줄래요?",
			"Hi, I'm Yuri from Customer Success. I handle Moonlight. We can ask the customer again, but replies will be slow at busy hours. Could you sort out what we can see first?"),
			"c02_ask", [
				["narrow", t("지금 기록으로 범위를 좁히고, 주문 번호만 더 부탁드릴게요.", "I'll narrow it down with our records and just ask for the order number.")],
				["code", t("코드부터 볼게요. 문의는 답이 올 때까지 열어 둘게요.", "I'll start with the code and keep the inquiry open until they reply.")],
				["direct", t("제가 고객에게 직접 물어봐도 될까요?", "Could I ask the customer directly?")]])
	resume()


func resume() -> void:
	var state := RequestLab.state()
	if state["opened"]:
		complete("ticket")
	if state["evidence"]:
		complete("evidence")
	if "request" in state["plan"] and "retries" in state["plan"]:
		complete("plan")
	if all_done():
		finish()


func on_event(kind: String, detail: Dictionary) -> void:
	if kind == "choice" and detail.get("key", "") == "c02_ask":
		Game.state["flags"]["c02_ask"] = detail["option"]
		match detail["option"]:
			"narrow":
				Game.relate("alex", {"work": 2})
				say("yuri", t("좋아요. 고객이 왜 필요한지 알 수 있게 한 문장만 붙여서 보낼게요. 이름이나 주소는 안 물어볼게요.", "Good. I'll add one sentence on why we need it. I won't ask for names or addresses."))
				_customer_followup()
			"code":
				say("daniel", t("가능해요. 다만 어떤 상황을 찾는지 먼저 적어 놓으세요. 비슷해 보이는 다른 버그를 고칠 수도 있으니까요.", "That works. Just write down what situation you're looking for first, or you might fix a different bug that looks similar."))
			"direct":
				Game.relate("alex", {"close": 2})
				say("yuri", t("같이 답장을 쓰죠. 처음에는 제가 보내고, 다음부터는 담당 범위를 맞춰 봐요.", "Let's write it together. I'll send the first one; after that we'll agree on who covers what."))
				_customer_followup()
		return
	if kind in ["ticket_opened", "ticket_evidence", "reproduction_plan"]:
		resume()


func _customer_followup() -> void:
	await wait(6.0)
	if Story.status(id) == "locked":
		return
	if once("_customer_followup"):
		Game.say("yuri", t("고객 답장 왔어요. “두 번째 주문 번호는 ORD-1044였어요. 둘 다 저녁 7시 2분쯤이었고, 결제 알림은 한 번만 왔어요.”",
			"The customer replied: “The second order number was ORD-1044. Both were around 7:02 PM, and I only got one payment notification.”"))
