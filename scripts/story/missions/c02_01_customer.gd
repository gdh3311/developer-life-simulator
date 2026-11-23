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


func on_event(kind: String, _detail: Dictionary) -> void:
	if kind in ["ticket_opened", "ticket_evidence", "reproduction_plan"]:
		resume()
