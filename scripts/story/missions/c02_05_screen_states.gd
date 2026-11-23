extends "res://scripts/story/mission.gd"
## C02 M05 — Sophie's screen maps a timeout to "failed" and retries with a new key.
## The player comments on her PR; they agree on screen states; Daniel merges the fix.


func _init() -> void:
	id = "c02_05"
	chapter = 2
	day = 6
	issue = "NXR-025"
	title = t("기다리는 사람의 화면", "The screen of someone waiting")
	objectives = [
		{"id": "review", "text": t("Sophie의 화면 상태 PR에 리뷰 코멘트 남기기", "Comment on Sophie's screen-state PR")},
		{"id": "agree", "text": t("Sophie와 '결과를 모르는 상태' 합의하기", "Agree with Sophie on the 'result unknown' state")},
		{"id": "merged", "text": t("합의대로 고친 PR 병합 확인", "See the agreed fix merged")},
	]
	hints = [
		t("CodeHub에서 Sophie의 PR → '변경 사항'을 여세요. 응답 종류마다 화면 상태와 keepKey가 어떻게 정해지는지 보세요.", "Open Sophie's PR → Changes in CodeHub. Check how each response kind sets the screen state and keepKey."),
		t("timeout은 서버가 실패했다는 뜻이 아니에요. 주문이 이미 만들어졌을 수도 있어요. 그때 '실패'라고 보여 주고 새 키로 다시 보내면 어떻게 될까요?", "A timeout doesn't mean the server failed. The order may already exist. What happens if the screen says 'failed' and resends with a new key?"),
		t("case 'timeout' 아래 줄을 선택하고 '문제 있음'으로 코멘트하세요.", "Select the line under case 'timeout' and comment with 'Problem'."),
	]


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue(issue, title, "review", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("sophie", "feature/order-screen", {
			"src/orders/order_status.ts": Workspace.content("c02/order_status.ts"),
			"tests/order_status.test.ts": Workspace.content("c02/order_status.test.ts"),
		}, "feat(orders): map order responses to screen states")
		if not is_current():
			return
		var p := await CodeHub.npc_pr("sophie", "feature/order-screen", "feat(orders): order screen states (NXR-025)",
			t("주문 응답을 화면 상태로 바꾸는 함수예요. 버튼은 이미 누르면 비활성화되게 했어요! 응답 종류별로 맞는지 봐 주세요.",
				"Maps order responses to screen states. The button already disables on click! Please check each response kind."), id)
		if not is_current():
			return
		data()["target"] = p["id"]
		data()["_prepared"] = true
	say("sophie", t("질문 하나만요. 실패했다고 나왔는데 주문이 있으면, 화면은 뭘 보여 줘야 해요? 일단 제 PR 먼저 봐 주실래요?",
		"Quick question. If it says 'failed' but the order exists, what should the screen show? Could you look at my PR first?"))


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"player_review":
			if int(d["pr"]) != int(data().get("target", -1)) or is_done("review"):
				return
			var texts: Array = (d["lines"] as Array).map(func(l: Dictionary) -> String: return String(l["text"]))
			var found := texts.any(func(x: String) -> bool: return "case 'timeout'" in x or ("state: 'failed'" in x and not "code" in x))
			var target := int(data()["target"])
			if d["verdict"] == "concern" and not found:
				Game.relate("sophie", {"agree": -2})
				CodeHub.comment(target, "sophie", t("음, 그 줄은 의도한 대로인 것 같아요. 어떤 응답에서 문제가 되는지 한 번만 더 짚어 주실래요?",
					"Hmm, that line looks intended. Could you point at which response causes trouble?"))
				return
			complete("review")
			if d["verdict"] == "concern":
				data()["found_by"] = "me"
				Game.relate("sophie", {"tech": 6})
				Game.relate("daniel", {"tech": 3})
				CodeHub.comment(target, "sophie", t("아... timeout을 실패로 보여 주면 고객은 다시 누르고, 새 키로 보내니까 서버가 막아 줄 수가 없네요.",
					"Oh... if timeout shows as failed, the customer clicks again with a new key, and the server can't protect them."))
			else:
				data()["found_by"] = "mina"
				Game.relate("daniel", {"tech": -2})
				CodeHub.comment(target, "mina", t("QA에서 봤는데요, 응답 지연을 걸면 화면에 '주문 실패'가 뜨고, 다시 누르니까 새 키로 주문이 하나 더 생겨요.",
					"From QA: with a delayed response the screen says 'order failed', and clicking again creates another order with a new key."))
			await wait(2.0)
			if not is_current():
				return
			choice("sophie", t("실패라고 쓰면 고객은 버튼을 다시 누를 거예요. 그런데 실패가 아니라 아직 모르는 거잖아요. 이걸 어떻게 보여 줄까요?",
				"If we say 'failed', customers will click again. But it isn't a failure; we just don't know yet. How should we show it?"),
				"c02_states", [
					["split", t("맞아요. 결과를 모르는 상태를 분리하죠. 같은 키로 확인하게요.", "Right. Let's separate 'result unknown' and check with the same key.")],
					["simple", t("응답 종류를 늘리면 복잡해질 것 같아요. 기존 상태로 설명할 수 있을까요?", "More states might get complicated. Can we explain it with the existing ones?")]])
		"choice":
			if d["key"] != "c02_states":
				return
			if d["option"] == "split":
				Game.relate("sophie", {"agree": 4, "close": 2})
				say("sophie", t("좋아요! '확인 중' 상태로 하고 키는 그대로 둘게요. 합의한 표는 Wiki에 올려 둘게요.",
					"Great! I'll add a 'checking' state and keep the key. I'll put the agreed table in the Wiki."))
			else:
				Game.relate("sophie", {"agree": 1})
				say("sophie", t("그럼 예시를 두 개만 놓고 볼까요? 실패한 경우랑, 주문은 생겼는데 답을 못 받은 경우요. ...둘을 같은 말로 부르면 안 되겠네요. 최소한으로 '확인 중'만 추가할게요.",
					"Then let's compare just two examples: a real failure, and an order created without a reply. ...They can't share a name. I'll add just a minimal 'checking' state."))
			complete("agree")
			Game.state["flags"]["c02_states_agreed"] = true
			await _sophie_fixes()
		"pr_merged":
			if int(d["pr"]) != int(data().get("target", -1)):
				return
			complete("merged")
			if once("_merge_reward"):
				if data().get("found_by", "") == "me":
					Game.relate("sophie", {"close": 3})
				else:
					Game.relate("mina", {"work": 2})
			await wait(1.5)
			if not is_current():
				return
			if data().get("found_by", "") == "mina":
				say("sophie", t("Mina 덕분에 QA에서 잡았네요. 다음엔 리뷰 때 응답 종류를 하나씩 대조해 봐요.",
					"Mina caught it in QA. Next time, let's walk through each response kind during review."))
			else:
				say("sophie", t("리뷰 고마워요. 버튼만 막으면 된다고 생각했는데, 화면이 서버와 약속을 지켜야 하는 거였네요.",
					"Thanks for the review. I thought disabling the button was enough, but the screen has to keep its promise with the server."))
			finish()


func _sophie_fixes() -> void:
	var target := int(data().get("target", -1))
	await wait(2.5)
	if not is_current():
		return
	await Workspace.bot_commit("sophie", "feature/order-screen", {
		"src/orders/order_status.ts": Workspace.content("c02/order_status_fixed.ts"),
		"tests/order_status.test.ts": Workspace.content("c02/order_status_fixed.test.ts"),
	}, "fix(orders): unknown result keeps the key and shows 'checking'")
	if not is_current():
		return
	await CodeHub.refresh_pr(target, t("Sophie가 합의한 화면 상태로 수정했습니다.", "Sophie updated the PR to the agreed screen states."))
	for i in 80:
		if CodeHub.get_pr(target)["ci"]["state"] != "running":
			break
		await wait(0.5)
	if not is_current():
		return
	CodeHub.review(target, "daniel", "approved", t("timeout은 확인 중, 키 유지. 서버의 중복 방지와 맞물리네요. 승인합니다.",
		"Timeout means checking with the same key. That fits the server's duplicate protection. Approved."))
	CodeHub.get_pr(target)["flags"]["hold_merge"] = false
	await wait(1.0)
	if is_current():
		await CodeHub.merge(target, "daniel")
