extends "res://scripts/story/mission.gd"
## Day 3, 10:30 — Feature #004 (shipping fee). Daniel's refactor causes a merge conflict;
## Alex pushes for speed before a demo.


func _init() -> void:
	id = "d3_07"
	day = 3
	title = t("배송비 기능 개발", "Shipping fee feature")
	issue = "#004"
	objectives = [
		{"id": "sync", "text": t("최신 main 받기 (Daniel이 올린 뼈대 코드)", "Get the latest main (Daniel's skeleton)")},
		{"id": "branch", "text": t("작업 브랜치 만들기", "Create a working branch")},
		{"id": "tests", "text": t("배송비 구현 + 테스트 통과 (경계값 테스트 추가)", "Implement shipping + pass tests (add boundary tests)")},
		{"id": "pr", "text": t("PR 만들기", "Open a PR")},
		{"id": "ci", "text": t("CI 통과 (충돌이 나면 해결)", "CI passes (resolve conflicts if any)")},
		{"id": "approved", "text": t("Daniel의 승인", "Daniel's approval")},
		{"id": "merged", "text": t("병합 (Daniel)", "Merged (by Daniel)")},
	]
	hints = [
		t("git switch main → git pull 로 Daniel이 올린 shipping.ts 뼈대와 테스트를 받으세요.", "git switch main → git pull to get Daniel's shipping.ts skeleton and test."),
		t("Wiki '배송비 정책': 5만원 이상 무료, 미만 3,000원, 도서산간은 항상 +5,000원, 0원 주문은 배송비 없음.", "Wiki 'Shipping policy': free from 50,000, otherwise 3,000; remote always +5,000; an empty order has no fee."),
		t("orderTotal(items, region) 도 배송비를 포함해야 해요. 그러면 기존 orders 테스트의 기대값도 정책에 맞게 바뀌어야 합니다.", "orderTotal(items, region) must include shipping too, so the expected value in the existing orders test changes."),
		t("충돌이 나면: 작업 브랜치에서 git pull origin main → <<<<<<< ======= >>>>>>> 표시 정리 (Daniel의 subtotal()도 살리기) → git add → git commit → git push",
			"On a conflict: git pull origin main on your branch → clean up <<<<<<< ======= >>>>>>> (keep Daniel's subtotal() too) → git add → git commit → git push"),
	]


func begin() -> void:
	Game.set_time(10 * 60 + 30)
	await Workspace.bot_commit("daniel", "main", {
		"src/orders/shipping.ts": Workspace.content("m06/shipping.ts"),
		"tests/shipping.test.ts": Workspace.content("m06/shipping.test.ts"),
	}, "chore(orders): shipping fee stub for #004")
	Game.add_issue("#004", Game.LL("주문 합계에 배송비 정책 추가", "Add the shipping policy to order totals"), "feature", Game.L("나", "me"), "progress")
	await wait(1.0)
	say("alex", t("오늘의 메인 업무예요! #004 배송비 정책을 주문 합계에 반영해야 해요. 정책은 Wiki '배송비 정책'에 있어요. 오후 3시 고객 데모에 보여 주고 싶어요!",
		"Today's main task! #004: add the shipping policy to order totals. It's in the Wiki under 'Shipping policy'. I want to show it in the 3 PM customer demo!"))
	await wait(2.5)
	say("daniel", t("shipping.ts 뼈대랑 테스트 하나 올려 뒀어요. pull 받고 시작하세요. 경계값 테스트 잊지 말고요.", "I pushed a shipping.ts skeleton and one test. Pull and start. Don't forget boundary tests."))


func hidden_tests() -> Dictionary:
	return load_tests("m06")


func review(p: Dictionary) -> void:
	if data().get("sneaky", false):
		return
	var n := await added_tests_count(p)
	if n >= 3:
		CodeHub.review(p["id"], "daniel", "approved", t("경계값(50,000원), 도서산간까지 테스트가 있네요. 승인합니다.", "Boundary (50,000) and remote cases are tested. Approved."))
		Game.relate("daniel", {"tech": 6})
		return
	if data().get("asked", false):
		CodeHub.review(p["id"], "daniel", "changes", t("테스트가 아직 %d개 추가됐네요. 경계값과 도서산간 케이스를 포함해서 3개 이상 부탁해요." % n,
			"Only %d tests added so far. Please add at least 3, including the boundary and remote cases." % n))
		Game.relate("daniel", {"work": -2})
		return
	data()["asked"] = true
	CodeHub.review(p["id"], "daniel", "changes",
		t("구현은 좋아요. 그런데 추가된 테스트가 %d개뿐이네요. 정책에 경계값(정확히 50,000원)과 도서산간 규칙이 있으니 테스트로 남겨 주세요." % n,
			"The implementation is good, but only %d tests were added. The policy has a boundary (exactly 50,000) and a remote rule; capture them in tests." % n),
		{"key": "d3_tests", "choices": [
			{"id": "fix", "label": t("경계값 테스트를 추가하겠습니다.", "I'll add boundary tests.")},
			{"id": "argue", "label": t("CI에 추가 검증 테스트가 있으니 충분하지 않을까요?", "CI has extra checks; isn't that enough?")}]})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"git_pushed":
			if d["branch"] == "main" or data().get("refactored", false):
				return
			data()["refactored"] = true
			await wait(1.5)
			await Workspace.bot_commit("daniel", "main", {"src/orders/orders.ts": Workspace.content("m06/orders_refactor.ts")},
				"refactor(orders): extract subtotal() and round totals")
			say("daniel", t("아 참, 방금 orders.ts 리팩터링(subtotal 분리)을 main에 넣었어요. 같은 파일을 건드렸다면 충돌이 날 수 있으니 확인 부탁해요!",
				"Heads up: I just merged an orders.ts refactor (extracted subtotal) into main. If you touched the same file you may get a conflict."))
		"pr_opened":
			if int(d["pr"]) != int(data().get("pr", 0)) or data().get("alex_asked", false):
				return
			data()["alex_asked"] = true
			await wait(3.0)
			choice("alex", t("데모가 3시인데... 리뷰 기다리지 말고 빨리 머지할 방법 없을까요?", "The demo is at 3... any way to merge faster without waiting for review?"), "d3_alex", [
				["honest", t("리뷰는 꼭 받아야 해요. 2시 반까지 맞춰 볼게요.", "It needs a review. I'll aim for 2:30.")],
				["ask", t("Daniel에게 리뷰를 먼저 봐 달라고 부탁해 볼게요.", "I'll ask Daniel to prioritise the review.")],
				["sneaky", t("Sophie에게 대신 승인해 달라고 할게요.", "I'll ask Sophie to approve it instead.")]])
		"choice":
			if d["key"] == "d3_alex":
				match d["option"]:
					"honest":
						Game.relate("alex", {"agree": -3, "work": 2})
						Game.relate("daniel", {"work": 4})
						say("alex", t("알겠어요, 2시 반까지만 부탁해요!", "Okay, 2:30 then!"))
					"ask":
						Game.relate("alex", {"work": 3})
						Game.relate("daniel", {"close": -1})
						say("daniel", t("데모 건이죠? CI 통과하면 바로 볼게요.", "For the demo? I'll look as soon as CI is green."))
					"sneaky":
						data()["sneaky"] = true
						Game.relate("sophie", {"agree": -6, "close": -3})
						say("sophie", t("어... 저는 승인 권한이 없어요. 그리고 Daniel한테 물어보지 않고 그러는 건 좀...", "Um... I don't have approval rights. And going around Daniel like that is..."))
						await wait(3.0)
						Game.relate("daniel", {"work": -10, "agree": -6})
						say("daniel", t("Sophie한테 승인 부탁했다고 들었어요. 리뷰를 우회하려는 건 신뢰 문제예요. 그러지 마세요.",
							"I heard you asked Sophie to approve. Trying to bypass review is a trust issue. Don't do that."))
						data()["sneaky"] = false
						var p := pr()
						if p["ci"]["state"] == "pass" and p["review"]["state"] == "pending" and p["mergeable"] != "conflict":
							review(p)
			elif d["key"] == "d3_tests":
				if d["option"] == "argue":
					Game.relate("daniel", {"agree": -4})
					CodeHub.comment(int(d["pr"]), "daniel", t("CI 검증 테스트는 안전망일 뿐이에요. 우리 코드의 스펙은 우리 테스트가 설명해야 합니다. 추가 부탁해요.",
						"The CI checks are a safety net. Our own tests should describe our spec. Please add them."))
				else:
					Game.relate("daniel", {"work": 2})
					CodeHub.comment(int(d["pr"]), "daniel", t("좋아요. push 하면 다시 볼게요.", "Good. I'll look again once you push."))
		"ci", "mergeable":
			if int(d["pr"]) == int(data().get("pr", 0)) and d.get("conflict", false):
				data()["conflict_seen"] = true
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				Game.relate("alex", {"work": 6, "close": 3})
				if data().get("conflict_seen", false):
					Game.relate("daniel", {"tech": 5})
					say("daniel", t("충돌 해결하면서 제 subtotal()까지 잘 살렸네요. 고마워요.", "You resolved the conflict and kept my subtotal(). Thanks."))
				await wait(2.0)
				say("alex", t("데모 대성공이에요! 고객이 배송비 계산이 명확해졌다고 좋아했어요.", "The demo went great! The customer loved how clear the shipping fees are now."))
				await wait(1.5)
				say("daniel", t("오늘도 수고 많았어요. 내일 저는 휴가라 급한 일 있으면 Sophie랑 Mina에게 부탁해요.", "Good work today. I'm off tomorrow, so lean on Sophie and Mina if anything urgent comes up."))
				finish()
