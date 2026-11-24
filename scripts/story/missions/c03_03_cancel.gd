extends "res://scripts/story/mission.gd"
## C03 M03 — the cancel button's second meaning. Don't invent a policy; ask, then split the states.


func _init() -> void:
	id = "c03_03"
	chapter = 3
	day = 9
	issue = "NXR-043"
	title = t("취소 버튼의 두 번째 의미", "The cancel button's second meaning")
	objectives = [
		{"id": "policy", "text": t("배송 준비 중 주문의 취소 정책 확인하기", "Confirm the cancel policy for orders in preparation")},
		{"id": "sync", "text": t("main 최신화로 취소 코드 받기", "Update main to get the cancel code")},
		{"id": "cancelfix", "text": t("취소·환불 요청·판매자 확인 상태를 나누고 테스트 통과", "Split cancel, refund request and seller review; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
	]
	hints = [
		t("정책이 비어 있으면 정답을 지어내지 말고 물어보세요. 채팅의 Daniel 질문에 답하면 됩니다.", "If the policy is blank, don't invent one; ask. Answer Daniel's question in chat."),
		t("Wiki '예약 주문 취소와 환불'의 표대로 단계(stage)와 결제 여부(paid)를 나누세요.", "Follow the table in the Wiki page 'Pre-order cancellation and refunds': split by stage and paid."),
	]


func begin() -> void:
	Game.set_time(9 * 60 + 10)
	Game.add_issue(issue, title, "feature", Game.L("나", "me"), "progress")
	say("system", t("네 번째 달 · 화요일", "Month four · Tuesday"), {"channel": "general", "silent": true})
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/preorder/cancel.ts": Workspace.content("c03/cancel.ts"),
			"tests/cancel.test.ts": Workspace.content("c03/cancel.test.ts"),
		}, "feat(preorder): cancel request skeleton")
		if not is_current():
			return
		data()["_prepared"] = true
	_ask_policy()


func _ask_policy() -> void:
	if is_done("policy") or Game.pending_choice("c03_policy"):
		return
	if int(data().get("policy_guesses", 0)) > 0:
		# A distinct line: say() would otherwise reuse the already-answered question.
		choice("daniel", t("다시 볼까요. 배송 준비 중인 주문, 누구에게 확인할래요?", "Let's try again. Orders in preparation: who will you check with?"), "c03_policy", [
			["ask", t("Alex에게 판매자 정책을 물어볼게요.", "I'll ask Alex about the seller policy.")]])
		return
	choice("daniel", t("취소 코드 올렸어요. 지금은 결제 전 취소와 결제 후 취소를 같은 '취소'로 저장해요. 그리고 배송 준비에 들어간 주문은 정책이 없어요. 어떻게 할래요?",
		"Cancel code is up. Right now paid and unpaid cancellations are saved as the same 'cancelled'. And there's no policy for orders already in preparation. What will you do?"),
		"c03_policy", [
			["ask", t("판매자 쪽 규칙은 Alex가 알 테니 물어볼게요.", "Alex knows the seller-side rule. I'll ask.")],
			["refund", t("일단 자동 환불로 넣을게요. 고객한테 좋잖아요.", "I'll make it an automatic refund for now. Good for buyers.")],
			["reject", t("배송 준비면 취소 불가로 막을게요.", "I'll just block cancellation once preparation starts.")]])


func hidden_tests() -> Dictionary:
	return load_tests("c03_03")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d.get("key", "") != "c03_policy":
				return
			if d["option"] == "ask":
				say("alex", t("판매자마다 달라요. 이미 포장했으면 판매자가 직접 보고 결정하고 싶대요. 자동 환불도 자동 거절도 안 돼요.",
					"It depends on the seller. If they've already packed it, they want to look and decide themselves. No automatic refund, no automatic rejection."))
				say("yuri", t("고객 문의도 그렇게 안내할게요. '판매자 확인 중'이면 기다리면 된다고요.", "I'll tell customers the same: 'seller reviewing' means please wait."))
				Game.state["flags"]["c03_cancel_policy"] = true
				Game.relate("alex", {"agree": 2})
				complete("policy")
			else:
				data()["policy_guesses"] = int(data().get("policy_guesses", 0)) + 1
				Game.relate("daniel", {"agree": -1})
				say("daniel", t("그건 우리가 정할 수 있는 게 아니에요. 돈이 오가는 규칙은 판매자와 정해야 해요. 정책이 없으면 지어내지 말고 물어봐요.",
					"That's not ours to decide. Rules that move money are set with the sellers. If there's no policy, don't invent one: ask."))
				await wait(1.0)
				if is_current():
					_ask_policy()
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/cancel.test.ts")):
				complete("cancelfix")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("daniel", {"tech": 3})
					Game.relate("alex", {"work": 2})
				await wait(1.2)
				if not is_current():
					return
				say("daniel", t("이제 정산에서 환불 기록이 사라지지 않아요. 나중에 환불 이관할 때 이 상태 표가 기준이 될 거예요.", "Refund records won't vanish in settlement now. This state table will anchor the refund migration later."))
				finish()
