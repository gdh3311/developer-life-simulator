extends "res://scripts/story/mission.gd"


func _init() -> void:
	id = "c02_02"
	chapter = 2
	day = 5
	issue = "NXR-022"
	title = t("재현되지 않습니다", "It does not reproduce")
	objectives = [
		{"id": "sync", "text": t("main을 최신화해 실험용 요청 코드 받기", "Update main to get the request module")},
		{"id": "baseline", "text": t("즉시 응답에서 주문 하나를 확인", "Observe one order with an immediate response")},
		{"id": "duplicate", "text": t("같은 키의 지연·재전송에서 중복 주문 재현", "Reproduce duplicate orders with a delayed response and the same key")},
		{"id": "isolate", "text": t("재시도를 끄고 같은 조건과 비교", "Disable retries and compare the result")},
	]
	hints = [
		t("git switch main → git pull로 새 파일을 받은 뒤 Request Lab의 '요청 실험'을 여세요.", "Run git switch main → git pull, then open Experiments in Request Lab."),
		t("클릭 1회·같은 키를 고정하세요. 즉시 응답 → 지연 응답+재시도 → 지연 응답+재시도 끄기를 비교해 보세요.", "Keep one click and the same key. Compare immediate response, delayed response with retry, then delayed response without retry."),
		t("이미 코드를 수정했다면 '신고된 버전'으로 원래 증상을 재현할 수 있어요. 현재 작업 파일은 덮어쓰지 않습니다.", "If you already edited the code, use Reported version to reproduce the original symptom. Your working file is preserved."),
	]


func begin() -> void:
	Game.set_time(9 * 60 + 20)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("mina", "main", {
			"src/orders/request.ts": Workspace.content("c02/request.ts"),
			"tests/request_store.ts": Workspace.content("c02/request_store.ts"),
			"tests/requests.test.ts": Workspace.content("c02/request.test.ts"),
		}, "test(orders): reproduce Moonlight retry issue")
		if not is_current():
			return
		data()["_prepared"] = true
	say("mina", t("즉시 응답만 확인하면 정상으로 보여요. 요청 코드와 테스트를 main에 올렸어요. Lab에서 지연과 재시도를 하나씩 바꿔 보세요.", "It looks normal with an immediate response. The module and tests are on main. Vary delay and retry one at a time in Lab."))
	say("daniel", t("지금은 왜 주문이 늘어나는지 찾는 단계예요. 테스트가 빨간 건 정상입니다. 코드는 다음 업무에서 고치죠.", "For now, find why the order count grows. Red tests are expected. We'll fix the code in the next task."))
	resume()


func resume() -> void:
	var synced := await Workspace.local_main_synced()
	if not is_current():
		return
	if synced:
		complete("sync")
	elif is_done("sync"):
		st()["obj"]["sync"] = false
		story.objectives_changed.emit()
	for run in RequestLab.state()["runs"]:
		_observe(run)
	_check_done()


func _observe(run: Dictionary) -> void:
	var config: Dictionary = run.get("config", {})
	if config.get("keys", "") != "same" or int(config.get("clicks", 0)) != 1:
		return
	if config.get("network", "") == "fast" and int(run.get("attempts", 0)) == 1 and int(run.get("created", 0)) == 1:
		complete("baseline")
	if config.get("network", "") == "slow" and config.get("retry", false) and int(run.get("attempts", 0)) == 2 and int(run.get("created", 0)) > 1:
		complete("duplicate")
	if config.get("network", "") == "slow" and not config.get("retry", true) and int(run.get("attempts", 0)) == 1 and int(run.get("created", 0)) == 1:
		complete("isolate")


func _check_done() -> void:
	if is_current() and data().get("_prepared", false) and all_done():
		say("sophie", t("버튼을 막아도 재전송은 남네요. 순차 요청부터 고쳐 봐요.", "Disabling the button won't stop a resend. Let's fix sequential requests first."))
		finish()


func on_event(kind: String, detail: Dictionary) -> void:
	if kind == "request_experiment":
		_observe(detail)
		_check_done()
	elif kind == "git_synced":
		resume()
