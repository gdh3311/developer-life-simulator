extends "res://scripts/story/mission.gd"
## Day 3, 09:00 — Leave review comments on Sophie's coupon PR. Juniors can't approve:
## Daniel decides. If nobody catches the bugs, day 4 has a payment incident.


func _init() -> void:
	id = "d3_06"
	day = 3
	title = t("첫 코드 리뷰 코멘트", "First review comments")
	issue = "#006"
	objectives = [
		{"id": "review", "text": t("Sophie의 쿠폰 PR에 리뷰 코멘트 남기기 (문제 줄 선택)", "Comment on Sophie's coupon PR (select the lines)")},
		{"id": "done", "text": t("Daniel의 최종 리뷰 확인", "See Daniel's final review")},
	]
	hints = [
		t("CodeHub에서 Sophie의 PR → '변경 사항' 탭을 열고 Wiki의 '쿠폰 정책'과 한 줄씩 비교해 보세요.", "In CodeHub, open Sophie's PR → 'Changes' and compare it line by line with the Wiki's 'Coupon policy'."),
		t("정률 쿠폰의 value 는 0~100 사이의 퍼센트 숫자예요. 10% 쿠폰이면 value = 10. 코드는 그걸 어떻게 쓰고 있나요?", "A percent coupon's value is a percentage 0-100. A 10% coupon has value = 10. How does the code use it?"),
		t("정액 쿠폰이 주문 금액보다 크면 결과가 어떻게 될까요?", "What happens if an amount coupon is bigger than the order total?"),
		t("문제 있는 줄을 클릭해서 선택한 뒤 '문제 있음'으로 코멘트하세요.", "Click the problematic lines to select them, then comment with 'Problem'."),
	]


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue("#006", Game.LL("쿠폰 할인 적용 (Sophie PR 리뷰)", "Coupon discounts (review Sophie's PR)"), "review", Game.L("나", "me"), "progress")
	await wait(1.0)
	say("system", t("DAY 3 · 수요일 아침입니다.", "DAY 3 · Wednesday morning."), {"channel": "general", "silent": true})
	await Workspace.bot_commit("sophie", "feature/coupon", {
		"src/orders/coupon.ts": Workspace.content("m05/coupon.ts"),
		"tests/coupon.test.ts": Workspace.content("m05/coupon.test.ts"),
	}, "feat(orders): apply coupon discount")
	var p := await CodeHub.npc_pr("sophie", "feature/coupon", "feat(orders): coupon discount (#006)",
		t("정률/정액 쿠폰 할인 적용 함수를 추가했어요. 첫 백엔드 PR이라 꼼꼼히 봐 주세요!", "Adds percent/amount coupon discounts. My first backend PR, so please look closely!"), id)
	data()["target"] = p["id"]
	say("daniel", t("Sophie PR, 저도 볼 건데 먼저 코멘트 남겨 줘요. 같은 주니어 눈으로 보는 것도 공부예요. 승인은 제가 합니다.",
		"I'll review Sophie's PR too, but leave your comments first. Reviewing as a junior is good practice. I'll do the approval."))
	await wait(1.5)
	say("sophie", t("좋은 아침이에요! 제 쿠폰 PR 의견 부탁드려요. 쿠폰 정책은 위키에 있어요!", "Morning! Could you comment on my coupon PR? The coupon policy is in the Wiki!"))


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "player_review" or int(d["pr"]) != int(data().get("target", -1)):
		return
	var texts: Array = (d["lines"] as Array).map(func(l: Dictionary) -> String: return String(l["text"]))
	var found_percent := texts.any(func(x: String) -> bool: return "total * coupon.value" in x)
	var found_negative := texts.any(func(x: String) -> bool: return "total - coupon.value" in x)
	var target := int(data()["target"])

	if d["verdict"] == "concern":
		if not (found_percent or found_negative):
			Game.relate("sophie", {"agree": -3})
			Game.relate("daniel", {"tech": -2})
			CodeHub.comment(target, "sophie", t("음.. 선택하신 줄은 스펙대로인 것 같은데요? 어떤 점이 문제일까요? 다시 한번 봐 주시겠어요?",
				"Hmm, those lines look like they follow the spec? What's the problem? Could you take another look?"))
			return
		complete("review")
		Game.relate("sophie", {"tech": 8, "agree": 3})
		Game.relate("daniel", {"tech": 6})
		CodeHub.comment(target, "sophie", t("아 맞네요! value가 퍼센트 숫자였죠. 다시 보니 0원 미만이 되는 문제도 있었어요. 바로 고칠게요.",
			"Oh, you're right! value is a percentage. Looking again, it can also go below zero. Fixing now.")
			if found_percent else t("음수 결제 금액이 나오겠네요. 다시 보니 정률 계산도 퍼센트를 안 나누고 있었어요. 고칠게요!",
			"That would charge a negative amount. And the percent math doesn't divide by 100 either. Fixing!"))
		await wait(3.0)
		await Workspace.bot_commit("sophie", "feature/coupon", {
			"src/orders/coupon.ts": Workspace.content("m05/coupon_fixed.ts"),
			"tests/coupon.test.ts": Workspace.content("m05/coupon_fixed.test.ts"),
		}, "fix(orders): percent coupons and negative totals (review)")
		await CodeHub.refresh_pr(target, t("Sophie가 리뷰를 반영해 새 커밋을 push 했습니다.", "Sophie pushed a commit addressing the review."))
		await _daniel_decides(target, t("%s 님이 정책 문서랑 대조해서 잘 잡았네요. 수정본 확인했고 승인합니다." % Game.pname(),
			"Good catch by %s, checked against the policy. I reviewed the fix and approve." % Game.pname()))
		say("daniel", t("리뷰 잘 봤어요. 이런 버그는 운영에서 잡으면 비싸요.", "Nice review. Bugs like this are expensive once they hit production."))
	else:
		complete("review")
		Game.state["flags"]["coupon_bug"] = true
		Game.relate("sophie", {"close": 2})
		await _daniel_decides(target, t("테스트 통과했고 %s 님도 LGTM이니 승인합니다." % Game.pname(), "Tests pass and %s says LGTM, so approved." % Game.pname()))
	complete("done")
	finish()


func _daniel_decides(target: int, text: Dictionary) -> void:
	for i in 60:
		if CodeHub.get_pr(target)["ci"]["state"] != "running":
			break
		await wait(0.5)
	await wait(2.0)
	CodeHub.review(target, "daniel", "approved", text)
	CodeHub.get_pr(target)["flags"]["hold_merge"] = false
	await wait(1.0)
	await CodeHub.merge(target, "daniel")
