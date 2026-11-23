extends "res://scripts/story/mission.gd"
## Day 3, 09:05 — Production incident: login hangs. The senior is on vacation.
## The player may delegate to the AI agent, whose patch looks fine but has a subtle bug.


func _init() -> void:
	id = "m07"
	day = 3
	title = "로그인 장애 대응"
	issue = "#007"
	default_reviewer = "sophie"
	objectives = [
		{"id": "monitor", "text": "Monitor에서 장애 상황 확인"},
		{"id": "sync", "text": "최신 main 받기"},
		{"id": "tests", "text": "로그인 타임아웃 처리 + 테스트 통과"},
		{"id": "pr", "text": "핫픽스 PR 만들기"},
		{"id": "ci", "text": "CI 통과"},
		{"id": "merged", "text": "PR 병합 (장애 해결)"},
	]
	hints = [
		"Monitor 로그를 보면 인증 서버(IdP)가 응답하지 않아 요청이 30초 넘게 매달려 있어요.",
		"Wiki '인증 / 장애 대응'에 스펙이 있어요: login(authenticate, userId, timeoutMs = 5000)",
		"Promise.race 로 authenticate() 와 타이머를 경쟁시키세요. 토큰 없음(AUTH_FAILED)과 시간 초과(AUTH_TIMEOUT)는 구분하고, 인증 서버가 던진 에러는 그대로 전달합니다.",
		"급하면 AICode에게 맡길 수도 있어요. 단, 결과는 꼭 직접 검토하고 테스트하세요.",
	]
	ai_task = {
		"label": "로그인 타임아웃 처리 (#007)",
		"files": {"src/auth/login.ts": "m07/ai_login.ts", "tests/login.test.ts": "m07/ai_login.test.ts"},
		"summary": "authenticate() 호출에 Promise.race로 타임아웃(기본 5초)을 추가하고 기본 동작 테스트를 작성했습니다.",
	}


func begin() -> void:
	Game.set_time(9 * 60 + 5)
	Game.add_issue("#007", "[P0] 로그인 무한 로딩 (인증 서버 응답 지연)", "bug", "나", "progress")
	monitor("auth", "down", "auth_down")
	await wait(1.0)
	say("system", "[ALERT] auth-service p99 latency > 30s · error rate 38%", {"channel": "general"})
	await wait(1.5)
	say("alex", "로그인이 안 된다는 고객 문의가 쏟아지고 있어요!! Daniel은 오늘 휴가라 연락이 안 돼요... 부탁드려요!")
	await wait(2.0)
	say("mina", "로그인 버튼을 누르면 무한 로딩이에요. Monitor 앱에서 로그를 확인해 보세요.")


func hidden_tests() -> Dictionary:
	return load_tests("m07")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	CodeHub.review(p["id"], "sophie", "approved", "백엔드는 아직 잘 모르지만... CI 통과했고 급하니까 승인할게요!")
	if not touches:
		CodeHub.comment(p["id"], "mina", "핫픽스라도 타임아웃 케이스 테스트는 있으면 좋겠어요. 다음 장애를 막아 주니까요.")


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"app_opened":
			if d["app"] == "monitor":
				complete("monitor")
		"ai_used":
			data()["ai_used"] = true
			Game.inc_stat("ai_used")
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) \
					and not data().get("ai_warned", false):
				data()["ai_warned"] = true
				say("ai", "CI에서 제 변경이 실패했네요. 모든 예외를 AUTH_TIMEOUT 으로 바꾸는 catch 블록이 원인일 수 있습니다. 검토 부탁드립니다.")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				monitor("auth", "ok", "normal")
				Game.relate("alex", {"work": 8, "close": 3})
				Game.relate("mina", {"work": 5})
				await wait(1.0)
				say("system", "[RESOLVED] auth-service 정상화 · error rate 0.2%", {"channel": "general"})
				await wait(1.5)
				say("alex", "로그인 정상화됐어요!! 정말 고마워요. 고객사에도 공지 나갔습니다.")
				finish()
