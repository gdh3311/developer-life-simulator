extends "res://scripts/story/mission.gd"
## C02 M06 — overlapping requests slip past "check then create". Use the store's atomic claim.

var _settling := false


func _init() -> void:
	id = "c02_06"
	chapter = 2
	day = 7
	issue = "NXR-026"
	title = t("버튼 바깥의 중복", "Duplicates beyond the button")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 동시 요청 테스트 받기", "Update main to get the concurrency tests")},
		{"id": "repro", "text": t("Lab '동시' 타이밍에서 중복 재현", "Reproduce duplicates with 'Concurrent' timing in Lab")},
		{"id": "concfix", "text": t("원자적 선점으로 고치고 테스트 통과", "Fix with an atomic claim and pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기 (해결한 경우를 설명에 남기기)", "Open the fix PR (describe which cases it covers)")},
		{"id": "ci", "text": t("추가 CI 동시성 검증 통과", "Pass the additional CI concurrency checks")},
		{"id": "merged", "text": t("Daniel의 검토와 병합", "Daniel reviews and merges")},
		{"id": "verified", "text": t("Lab 현재 코드: 동시 요청 2번 → 주문 1개 확인", "Verify in Lab: two concurrent calls → one order with current code")},
	]
	hints = [
		t("git switch main → git pull 후 Request Lab에서 '요청 타이밍: 동시', 응답 지연, 재전송 켬, 같은 키로 실행해 보세요.", "git switch main → git pull, then in Request Lab run with timing Concurrent, delayed response, retry on, same key."),
		t("get으로 확인하고 create로 만드는 사이에 다른 요청이 끼어들어요. Wiki '동시 요청과 선점'의 store.claim은 이 판정을 한 번에 해요.", "Another request slips in between get and create. store.claim in the Wiki page 'Concurrent requests and claims' decides it in one step."),
		t("claim 결과가 'new'면 만들고 complete, 'pending'이면 wait를 기다리고, 'done'이면 order를 돌려줘요. fingerprint가 다르면 REQUEST_CONFLICT. 만들다 실패하면 release!", "If claim says 'new', create then complete; 'pending' → await wait; 'done' → return order. Different fingerprint → REQUEST_CONFLICT. On failure, release!"),
		t("AICode 초안도 있어요. 설명에 적힌 '검증하지 않은 범위'를 꼭 확인하세요.", "There's an AICode draft too. Check the 'not validated' scope in its description."),
	]
	ai_task = {
		"label": t("동시 요청 선점 처리", "Concurrent claim handling"),
		"files": {"src/orders/request.ts": "c02/request_concurrent_ai.ts"},
		"summary": t("claim/complete/release로 동시 요청과 생성 실패 복구를 처리했습니다. 생성 중(pending)일 때의 내용 비교는 검증하지 않았습니다.",
			"Handled concurrent calls and creation failures with claim/complete/release. Content comparison while a claim is pending was not validated."),
	}


func begin() -> void:
	Game.set_time(9 * 60 + 5)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("mina", "main", {
			"tests/request_store.ts": Workspace.content("c02/request_store_v2.ts"),
			"tests/requests_concurrent.test.ts": Workspace.content("c02/requests_concurrent.test.ts"),
		}, "test(orders): overlapping requests reproduce duplicates")
		if not is_current():
			return
		data()["_prepared"] = true
	say("system", t("두 번째 달 · 수요일", "Month two · Wednesday"), {"channel": "general", "silent": true})
	say("mina", t("두 작업자를 같은 시점에 시작한 테스트를 올렸어요. 순차 요청에서는 통과하던 코드가 주문 두 개를 만들어요. 확인하고 저장하는 사이에 둘 다 들어갔어요.",
		"I pushed a test that starts two workers at the same moment. Code that passed sequential calls creates two orders. Both got in between the check and the save."))
	await wait(1.5)
	if not is_current():
		return
	say("daniel", t("키가 있는지 먼저 보는 것만으로는 안 돼요. 누가 먼저 맡았는지를 한 번에 정해야 해요. 저장소 쪽 약속(claim)을 보세요. Wiki에 정리해 뒀어요.",
		"Checking whether the key exists isn't enough. Who claims it first has to be decided in one step. Look at the store's claim contract; it's in the Wiki."))
	resume()


func hidden_tests() -> Dictionary:
	return load_tests("c02_06")


func resume() -> void:
	for run in RequestLab.state()["runs"]:
		_observe(run)
	super.resume()
	_check_done()


func _observe(run: Dictionary) -> void:
	var config: Dictionary = run.get("config", {})
	if config.get("timing", "sequential") != "concurrent" or config.get("keys", "") != "same" or int(run.get("attempts", 0)) < 2:
		return
	if int(run.get("created", 0)) > 1:
		complete("repro")
	if config.get("version", "") == "current" and int(run.get("created", 0)) == 1 \
			and run.get("code_hash", "") == Workspace.read_file("src/orders/request.ts").sha256_text():
		data()["verified_hash"] = run["code_hash"]
		complete("verified")


func review(p: Dictionary) -> void:
	var body := String(p.get("body", "")).to_lower()
	var explained := body.length() >= 20
	if not is_current():
		return
	if explained:
		CodeHub.review(p["id"], "daniel", "approved", t("동시 요청, 실패 뒤 재시도, 생성 중 충돌까지 확인했네요. 설명에 범위가 적혀 있어서 리뷰하기 쉬웠어요. 승인합니다.",
			"Concurrent calls, retry after failure, and conflicts while pending are covered. The scope in the description made this easy to review. Approved."))
		Game.relate("daniel", {"tech": 5, "work": 2})
	else:
		CodeHub.review(p["id"], "daniel", "approved", t("코드는 맞아요. 다만 이런 변경은 어떤 경우를 해결했는지 설명에 남겨 주세요. 다음 사람이 범위를 알아야 하니까요.",
			"The code is right. For a change like this, note which cases it covers in the description. The next person needs to know the scope."))
		Game.relate("daniel", {"tech": 3})


func _check_done() -> void:
	if not is_current() or _settling or not all_done():
		return
	if data().get("verified_hash", "") != Workspace.read_file("src/orders/request.ts").sha256_text():
		return
	_settling = true
	if once("_merge_reward"):
		Game.relate("mina", {"tech": 4})
	say("daniel", t("이제 겹쳐 들어와도 같은 주문이네요. 남은 건 실제 고객 환경에 적용하고 확인하는 일이에요. 오후에 Alex랑 같이 봐요.",
		"Now overlapping requests return the same order too. What's left is applying it for the customer and checking. Let's go over it with Alex this afternoon."))
	finish()


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"request_experiment":
			_observe(d)
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/requests_concurrent.test.ts")):
				complete("concfix")
		"file_saved":
			if d.get("path", "") == "src/orders/request.ts" and data().get("verified_hash", "") != Workspace.read_file("src/orders/request.ts").sha256_text():
				st()["obj"]["verified"] = false
				story.objectives_changed.emit()
		"ai_used":
			data()["ai_used"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and once("_ai_note"):
				say("ai", t("CI에서 제 초안이 '생성 중인 같은 키에 다른 내용' 검사에 실패했네요. 설명에 적은 대로 pending 상태의 내용 비교를 하지 않았습니다.",
					"My draft failed CI's 'different contents while the key is being created' check. As stated, it didn't compare contents for a pending claim."))
	_check_done()
