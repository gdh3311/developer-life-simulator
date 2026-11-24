extends "res://scripts/story/mission.gd"

var _settling := false


func _init() -> void:
	id = "c02_03"
	chapter = 2
	day = 5
	issue = "NXR-023"
	title = t("같은 요청 두 번", "The same request twice")
	objectives = [
		{"id": "tests", "text": t("순차 요청 정책을 구현하고 로컬 테스트 통과", "Implement the sequential request contract and pass local tests")},
		{"id": "pr", "text": t("작업 브랜치에서 수정 PR 만들기", "Open the fix PR from a working branch")},
		{"id": "ci", "text": t("공개된 정책의 추가 CI 검증 통과", "Pass additional CI checks for the published policy")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
		{"id": "verified", "text": t("Lab 현재 코드에서 재전송 2번 → 주문 1개 확인", "Verify two calls → one order with current code in Lab")},
	]
	hints = [
		t("Wiki '주문 요청과 재시도'의 계약을 읽고 src/orders/request.ts를 수정하세요. 작업 브랜치를 만든 뒤 기존 Git 흐름으로 PR을 올리면 됩니다.", "Read Order requests and retries in Wiki, then edit src/orders/request.ts on a working branch and use the familiar PR flow."),
		t("키를 trim하고, 상점 ID와 키의 쌍으로 이전 주문을 찾아야 해요. 같은 키에 다른 items가 오면 REQUEST_CONFLICT입니다.", "Trim the key and look up the shop/key pair. Different items under the same pair must throw REQUEST_CONFLICT."),
		t("예: key = JSON.stringify([request.shopId, requestKey]), fingerprint = JSON.stringify(request.items). store.get/set은 완료된 주문을 기억합니다.", "For example: key = JSON.stringify([request.shopId, requestKey]), fingerprint = JSON.stringify(request.items). store.get/set remembers completed orders."),
		t("AICode의 순차 구현 초안을 써도 돼요. 아직 동시성은 해결하지 않았다는 범위를 확인하고 테스트와 Lab으로 검증하세요.", "You may use AICode's sequential draft. Note that concurrency remains unsolved, then verify with tests and Lab."),
	]
	ai_task = {
		"label": t("주문 순차 재시도 계약", "Sequential order retry contract"),
		"files": {"src/orders/request.ts": "c02/request_sequential.ts"},
		"bases": {"src/orders/request.ts": "c02/request.ts"},
		"summary": t("순차 재시도·내용 충돌·빈 키 처리를 구현했습니다. 검증 범위는 순차 요청입니다.", "Implemented sequential retries, content conflicts, and empty keys. Validation scope: sequential calls."),
	}


func begin() -> void:
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	say("daniel", t("같은 요청이면 같은 결과로 연결하는 걸 멱등성이라고 해요. 이번에는 순차 재전송부터 지킵시다. 동시 요청과 실제 고객 적용은 다음 확인이에요.", "Returning the same result for the same request is idempotency. Start with sequential resends. Concurrent calls and customer rollout are later checks."))
	say("mina", t("정책과 공개 테스트가 같은 규칙을 설명해요. CI는 그 규칙의 입력을 넓혀 확인합니다. Lab에서는 '현재 작업 코드'를 골라 결과를 비교해 주세요.", "Policy and public tests describe the same contract. CI adds inputs within that contract. In Lab, choose Current working code to compare the result."))
	if not data().has("policy_q") and not Game.pending_choice("c02_policy_q"):
		choice("daniel", t("Wiki에 정책 초안 올려 뒀어요. 코드 보기 전에 궁금한 거 있으면 지금 물어봐요.", "The policy draft is in the Wiki. If anything's unclear, ask before you touch the code."),
			"c02_policy_q", [
				["ask", t("같은 키인데 상품이 바뀌면 새 주문으로 봐야 하나요?", "If the key is the same but the items change, is that a new order?")],
				["skip", t("일단 테스트 예제로 확인해 볼게요.", "I'll check the test examples first.")]])
	resume()


func hidden_tests() -> Dictionary:
	return load_tests("c02")


func resume() -> void:
	for run in RequestLab.state()["runs"]:
		_observe(run)
	super.resume()
	_check_done()


func _observe(run: Dictionary) -> void:
	var config: Dictionary = run.get("config", {})
	if config.get("version", "") == "current" and config.get("network", "") == "slow" and config.get("retry", false) and config.get("keys", "") == "same" and int(config.get("clicks", 0)) == 1 and int(run.get("attempts", 0)) == 2 and int(run.get("created", 0)) == 1 and run.get("code_hash", "") == Workspace.read_file("src/orders/request.ts").sha256_text():
		data()["verified_hash"] = run["code_hash"]
		complete("verified")


func _check_done() -> void:
	if not is_current() or _settling or not all_done():
		return
	if data().get("verified_hash", "") != Workspace.read_file("src/orders/request.ts").sha256_text():
		return
	_settling = true
	if once("_merge_reward"):
		Game.relate("daniel", {"tech": 5})
		Game.relate("mina", {"work": 3})
	say("daniel", t("순차 요청은 같은 주문으로 돌아오네요. 범위를 정확히 적어 둡시다. 다음에는 로그, 화면 상태, 동시에 겹치는 요청을 확인해야 해요.", "Sequential requests now return one order. Keep the scope explicit. Logs, screen states, and overlapping calls still need work."))
	monitor("api", "warn", "order_observing")
	finish()


func on_event(kind: String, detail: Dictionary) -> void:
	if kind == "choice" and detail.get("key", "") == "c02_policy_q":
		data()["policy_q"] = detail["option"]
		if detail["option"] == "ask":
			Game.relate("daniel", {"agree": 2})
			say("alex", t("고객 입장에서는 새 주문일 수도 있는데, 실수일 수도 있겠네요.", "From the customer's side it might be a new order, or it might be a mistake."))
			say("mina", t("같은 키로 조용히 다른 주문이 생기면 추적이 안 돼요. 다른 키로 다시 요청하도록 구분하면 어떨까요?", "If a different order silently appears under the same key, we can't trace it. How about making them resend with a new key?"))
			say("daniel", t("좋아요. 그건 REQUEST_CONFLICT로 돌려주고, 그 규칙을 API 예시에 같이 적죠.", "Good. Return REQUEST_CONFLICT for that, and put the rule in the API examples."))
		else:
			say("mina", t("좋아요. 같은 키에 다른 상품이 오는 경우도 공개 테스트 예제에 있어요.", "Sure. The same-key-different-items case is in the public test examples too."))
		return
	if kind == "request_experiment":
		_observe(detail)
	elif kind == "file_saved" and detail.get("path", "") == "src/orders/request.ts":
		if data().get("verified_hash", "") != Workspace.read_file("src/orders/request.ts").sha256_text():
			st()["obj"]["verified"] = false
			story.objectives_changed.emit()
	_check_done()
