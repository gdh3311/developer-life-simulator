extends "res://scripts/story/mission.gd"
## Day 2, 10:30 — Feature #004 (shipping fee). Daniel's refactor causes a merge conflict;
## Alex pushes to skip the review before a demo.


func _init() -> void:
	id = "m06"
	day = 2
	title = "배송비 기능 개발"
	issue = "#004"
	objectives = [
		{"id": "sync", "text": "최신 main 받기 (Daniel이 올린 뼈대 코드)"},
		{"id": "branch", "text": "작업 브랜치 만들기"},
		{"id": "tests", "text": "배송비 구현 + 테스트 통과 (경계값 테스트 추가)"},
		{"id": "pr", "text": "PR 만들기"},
		{"id": "ci", "text": "CI 통과 (충돌이 나면 해결)"},
		{"id": "approved", "text": "리뷰 승인"},
		{"id": "merged", "text": "PR 병합하기"},
	]
	hints = [
		"git switch main → git pull 로 Daniel이 올린 shipping.ts 뼈대와 테스트를 받으세요.",
		"Wiki '배송비 정책': 5만원 이상 무료, 미만 3,000원, 도서산간은 항상 +5,000원, 0원 주문은 배송비 없음.",
		"orderTotal(items, region) 도 배송비를 포함해야 해요. 그러면 기존 orders 테스트의 기대값도 정책에 맞게 바뀌어야 합니다.",
		"PR에 충돌이 나면: 작업 브랜치에서 git pull origin main → <<<<<<< ======= >>>>>>> 표시를 정리 (Daniel의 subtotal()도 살리기) → git add → git commit → git push",
	]


func begin() -> void:
	Game.set_time(10 * 60 + 30)
	await Workspace.bot_commit("daniel", "main", {
		"src/orders/shipping.ts": Workspace.content("m06/shipping.ts"),
		"tests/shipping.test.ts": Workspace.content("m06/shipping.test.ts"),
	}, "chore(orders): shipping fee stub for #004")
	Game.add_issue("#004", "주문 합계에 배송비 정책 추가", "feature", "나", "progress")
	await wait(1.0)
	say("alex", "다음 업무예요! #004 배송비 정책을 주문 합계에 반영해야 해요. 정책은 Wiki '배송비 정책'에 정리해 뒀어요. 오후 3시 고객 데모에 꼭 보여 주고 싶어요!")
	await wait(2.5)
	say("daniel", "shipping.ts 뼈대랑 테스트 하나 올려 뒀어요. pull 받고 시작하세요. 경계값 테스트 잊지 말고요.")


func hidden_tests() -> Dictionary:
	return load_tests("m06")


func review(p: Dictionary) -> void:
	if p["flags"].get("skip_review", false):
		return
	var n := await added_tests_count(p)
	if n >= 3:
		CodeHub.review(p["id"], "daniel", "approved", "경계값(50,000원), 도서산간까지 테스트가 있네요. 승인합니다.")
		Game.relate("daniel", {"tech": 6})
		return
	if data().get("asked", false):
		CodeHub.review(p["id"], "daniel", "changes", "테스트가 아직 %d개 추가됐네요. 경계값과 도서산간 케이스를 포함해서 3개 이상 부탁해요." % n)
		return
	data()["asked"] = true
	CodeHub.review(p["id"], "daniel", "changes",
		"구현은 좋아요. 그런데 추가된 테스트가 %d개뿐이네요. 정책에 경계값(정확히 50,000원)과 도서산간 규칙이 있으니 테스트로 남겨 주세요." % n,
		{"key": "m06_tests", "choices": [
			{"id": "fix", "label": "경계값 테스트를 추가하겠습니다."},
			{"id": "argue", "label": "CI에 추가 검증 테스트가 있으니 충분하지 않을까요?"}]})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"git_pushed":
			# While the player works on the feature, Daniel lands a refactor of the same file.
			if d["branch"] == "main" or data().get("refactored", false):
				return
			data()["refactored"] = true
			await wait(1.5)
			await Workspace.bot_commit("daniel", "main", {
				"src/orders/orders.ts": Workspace.content("m06/orders_refactor.ts"),
			}, "refactor(orders): extract subtotal() and round totals")
			say("daniel", "아 참, 방금 orders.ts 리팩터링(subtotal 분리)을 main에 넣었어요. 같은 파일을 건드렸다면 충돌이 날 수 있으니 PR 올릴 때 확인 부탁해요!")
		"pr_opened":
			if int(d["pr"]) != int(data().get("pr", 0)) or data().get("alex_asked", false):
				return
			data()["alex_asked"] = true
			await wait(3.0)
			choice("alex", "데모가 3시인데... 리뷰 기다리지 말고 바로 머지해 주실 수 있어요?", "m06_alex", [
				["wait", "리뷰까지 받고 2시 반까지 드릴게요."],
				["rush", "네, 리뷰 없이 바로 머지할게요."]])
		"choice":
			if d["key"] == "m06_alex":
				var p := pr()
				if d["option"] == "rush":
					p["flags"]["skip_review"] = true
					Game.relate("alex", {"work": 5})
					Game.relate("daniel", {"work": -6, "agree": -4})
					complete("approved")
					CodeHub.comment(p["id"], "daniel", "리뷰 없이 머지는 위험해요... 이번만입니다. CI는 꼭 통과시켜 주세요.")
				else:
					Game.relate("alex", {"agree": -3, "work": 2})
					Game.relate("daniel", {"work": 5})
					say("alex", "알겠어요, 2시 반까지만 부탁해요!")
			elif d["key"] == "m06_tests":
				if d["option"] == "argue":
					Game.relate("daniel", {"agree": -4})
					CodeHub.comment(int(d["pr"]), "daniel", "CI 검증 테스트는 안전망일 뿐이에요. 우리 코드의 스펙은 우리 테스트가 설명해야 합니다. 추가 부탁해요.")
				else:
					Game.relate("daniel", {"work": 3})
					CodeHub.comment(int(d["pr"]), "daniel", "좋아요. push 하면 다시 볼게요.")
		"ci", "mergeable":
			if int(d["pr"]) == int(data().get("pr", 0)) and d.get("conflict", false):
				data()["conflict_seen"] = true
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				Game.relate("alex", {"work": 6, "close": 3})
				if data().get("conflict_seen", false):
					Game.relate("daniel", {"tech": 5})
					say("daniel", "충돌 해결하면서 제 subtotal()까지 잘 살렸네요. 고마워요.")
				await wait(2.0)
				say("alex", "데모 대성공이에요! 고객이 배송비 계산이 명확해졌다고 좋아했어요.")
				await wait(1.5)
				say("daniel", "오늘도 수고 많았어요. 내일 저는 휴가라 급한 일 있으면 Sophie랑 Mina에게 부탁해요.")
				finish()
