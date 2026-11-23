extends "res://scripts/story/mission.gd"
## Day 2, 09:00 — Review Sophie's coupon PR. Approving it with bugs causes an incident on day 3.


func _init() -> void:
	id = "m05"
	day = 2
	title = "첫 코드 리뷰"
	issue = "#006"
	objectives = [
		{"id": "review", "text": "Sophie의 쿠폰 PR 리뷰하기 (문제 줄 선택 → 판정)"},
		{"id": "done", "text": "리뷰 마무리 (승인 후 병합)"},
	]
	hints = [
		"CodeHub에서 Sophie의 PR → '변경 사항' 탭을 열고, Wiki의 '쿠폰 정책'과 한 줄씩 비교해 보세요.",
		"정률 쿠폰의 value 는 0~100 사이의 퍼센트 숫자예요. 10% 쿠폰이면 value = 10 입니다. 코드는 그걸 어떻게 쓰고 있나요?",
		"정액 쿠폰이 주문 금액보다 크면 결과가 어떻게 될까요? 정책에는 뭐라고 되어 있죠?",
		"문제 있는 줄을 클릭해서 선택한 뒤 '변경 요청'을 누르세요. 문제가 없다고 판단되면 '승인'을 누르면 됩니다.",
	]


func begin() -> void:
	Game.add_issue("#006", "쿠폰 할인 적용 (Sophie PR 리뷰)", "review", "나", "progress")
	await wait(1.0)
	say("system", "DAY 2 · 화요일 아침입니다.", {"channel": "general", "silent": true})
	await Workspace.bot_commit("sophie", "feature/coupon", {
		"src/orders/coupon.ts": Workspace.content("m05/coupon.ts"),
		"tests/coupon.test.ts": Workspace.content("m05/coupon.test.ts"),
	}, "feat(orders): apply coupon discount")
	var p := await CodeHub.npc_pr("sophie", "feature/coupon", "feat(orders): 쿠폰 할인 적용 (#006)",
		"정률/정액 쿠폰 할인 적용 함수를 추가했어요. 첫 백엔드 PR이라 꼼꼼히 봐 주세요!", id)
	data()["target"] = p["id"]
	say("sophie", "좋은 아침이에요! 제 첫 백엔드 PR인데 리뷰 부탁드려도 될까요? 쿠폰 정책은 위키에 있어요!")


func on_event(kind: String, d: Dictionary) -> void:
	if kind != "player_review" or int(d["pr"]) != int(data().get("target", -1)):
		return
	var texts: Array = (d["lines"] as Array).map(func(l: Dictionary) -> String: return String(l["text"]))
	var found_percent := texts.any(func(t: String) -> bool: return "total * coupon.value" in t)
	var found_negative := texts.any(func(t: String) -> bool: return "total - coupon.value" in t)
	var target := int(data()["target"])

	if d["verdict"] == "changes":
		if not (found_percent or found_negative):
			Game.relate("sophie", {"agree": -5})
			CodeHub.comment(target, "sophie", "음.. 선택하신 줄은 스펙대로인 것 같은데요? 혹시 어떤 점이 문제일까요? 다시 한번 봐 주시겠어요?")
			return
		complete("review")
		data()["fixed"] = true
		Game.relate("sophie", {"tech": 8, "agree": 3})
		Game.relate("daniel", {"tech": 5})
		var both := found_percent and found_negative
		CodeHub.comment(target, "sophie", "아 맞네요! %s 바로 고칠게요." % (
			"value가 퍼센트 숫자인 것도, 0원 미만이 되는 것도 놓쳤네요." if both else
			("value가 퍼센트 숫자였죠. 다시 보니 0원 미만이 되는 문제도 있더라고요." if found_percent else
			"음수 결제 금액이 나오겠네요. 다시 보니 정률 계산도 퍼센트를 안 나누고 있었어요.")))
		await wait(3.0)
		await Workspace.bot_commit("sophie", "feature/coupon", {
			"src/orders/coupon.ts": Workspace.content("m05/coupon_fixed.ts"),
			"tests/coupon.test.ts": Workspace.content("m05/coupon_fixed.test.ts"),
		}, "fix(orders): percent coupons and negative totals (review)")
		await CodeHub.refresh_pr(target, "Sophie가 리뷰를 반영해 새 커밋을 push 했습니다.")
		CodeHub.comment(target, "sophie", "리뷰 반영했어요! (정률 계산, 0원 미만 방지 + 테스트 추가) 다시 봐 주세요.")
		say("daniel", "Sophie PR 리뷰 봤어요. 정책 문서랑 대조해서 잡아낸 거 좋네요.")
		return

	# approve
	complete("review")
	if not data().get("fixed", false):
		Game.state["flags"]["coupon_bug"] = true
		Game.relate("sophie", {"close": 3})
		CodeHub.comment(target, "sophie", "승인 감사합니다! 바로 머지할게요~")
	else:
		Game.relate("sophie", {"close": 4, "work": 3})
		CodeHub.comment(target, "sophie", "꼼꼼하게 봐 주셔서 감사해요! 머지할게요.")
	await wait(2.0)
	for i in 60:
		if CodeHub.get_pr(target)["ci"]["state"] != "running":
			break
		await wait(0.5)
	await CodeHub.merge(target, "sophie")
	complete("done")
	finish()
