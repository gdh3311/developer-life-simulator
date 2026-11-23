extends "res://scripts/story/mission.gd"
## Day 4, 09:05 — Production incident: login hangs. The senior is on vacation.
## The player may delegate to the AI agent, whose patch looks fine but has a subtle bug.


func _init() -> void:
	id = "d4_08"
	day = 4
	title = t("로그인 장애 대응", "Login outage")
	issue = "#007"
	default_reviewer = "mina"
	objectives = [
		{"id": "monitor", "text": t("Monitor에서 장애 상황 확인", "Check the outage in Monitor")},
		{"id": "sync", "text": t("최신 main 받기", "Get the latest main")},
		{"id": "tests", "text": t("로그인 타임아웃 처리 + 테스트 통과", "Add a login timeout + pass tests")},
		{"id": "pr", "text": t("핫픽스 PR 만들기", "Open a hotfix PR")},
		{"id": "ci", "text": t("CI 통과", "CI passes")},
		{"id": "merged", "text": t("병합 (장애 해결)", "Merged (outage resolved)")},
	]
	hints = [
		t("Monitor 로그를 보면 인증 서버(IdP)가 응답하지 않아 요청이 30초 넘게 매달려 있어요.", "Monitor shows the identity provider not answering, so requests hang for 30+ seconds."),
		t("Wiki '인증 / 장애 대응'에 스펙이 있어요: login(authenticate, userId, timeoutMs = 5000)", "The Wiki 'Auth & incidents' page has the spec: login(authenticate, userId, timeoutMs = 5000)"),
		t("Promise.race 로 authenticate() 와 타이머를 경쟁시키세요. 토큰 없음(AUTH_FAILED)과 시간 초과(AUTH_TIMEOUT)는 구분하고, 인증 서버 에러는 그대로 전달합니다.",
			"Race authenticate() against a timer with Promise.race. Keep 'no token' (AUTH_FAILED) separate from a timeout (AUTH_TIMEOUT), and pass identity-provider errors through."),
		t("급하면 AICode에게 맡길 수도 있어요. 단, 결과는 꼭 직접 검토하고 테스트하세요.", "If you're in a hurry, AICode can take it. But review and test what it writes."),
	]
	ai_task = {
		"label": t("로그인 타임아웃 처리 (#007)", "Login timeout (#007)"),
		"files": {"src/auth/login.ts": "m07/ai_login.ts", "tests/login.test.ts": "m07/ai_login.test.ts"},
		"summary": t("authenticate() 호출에 Promise.race로 타임아웃(기본 5초)을 추가하고 기본 동작 테스트를 작성했습니다.",
			"Added a Promise.race timeout (default 5s) around authenticate() and wrote a basic test."),
	}


func begin() -> void:
	Game.set_time(9 * 60 + 5)
	Game.add_issue("#007", Game.LL("[P0] 로그인 무한 로딩 (인증 서버 응답 지연)", "[P0] Login spins forever (identity provider not responding)"), "bug", Game.L("나", "me"), "progress")
	monitor("auth", "down", "auth_down")
	await wait(1.0)
	if not is_current():
		return
	say("system", t("[ALERT] auth-service p99 latency > 30s · error rate 38%", "[ALERT] auth-service p99 latency > 30s · error rate 38%"), {"channel": "general"})
	await wait(1.5)
	if not is_current():
		return
	say("alex", t("로그인이 안 된다는 고객 문의가 쏟아지고 있어요!! Daniel은 오늘 휴가라 연락이 안 돼요... 부탁드려요!",
		"Customers are flooding us: nobody can log in!! Daniel is on vacation and unreachable... please help!"))
	await wait(2.0)
	if not is_current():
		return
	say("mina", t("로그인 버튼을 누르면 무한 로딩이에요. Monitor 앱에서 로그를 확인해 보세요. 오늘 리뷰는 제가 볼게요.",
		"Login spins forever. Check the logs in Monitor. I'll do the review today."))


func hidden_tests() -> Dictionary:
	return load_tests("m07")


func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if not is_current():
		return
	CodeHub.review(p["id"], "mina", "approved", t("CI 통과 확인했어요. 장애 중이니 바로 병합할게요!", "CI is green. We're mid-outage, so merging right away!"))
	if not touches:
		CodeHub.comment(p["id"], "mina", t("핫픽스라도 타임아웃 케이스 테스트는 있으면 좋겠어요. 다음 장애를 막아 주니까요.", "Even for a hotfix, a timeout test would be good. It prevents the next outage."))
		Game.relate("mina", {"tech": -2})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"app_opened":
			if d["app"] == "monitor":
				complete("monitor")
		"ai_used":
			data()["ai_used"] = true
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and data().get("ai_used", false) and not data().get("ai_warned", false):
				data()["ai_warned"] = true
				say("ai", t("CI에서 제 변경이 실패했네요. 모든 예외를 AUTH_TIMEOUT 으로 바꾸는 catch 블록이 원인일 수 있습니다. 검토 부탁드립니다.",
					"My change failed CI. The catch block that turns every error into AUTH_TIMEOUT may be the cause. Please review it."))
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				monitor("auth", "ok", "normal")
				if once("_merge_reward"):
					Game.relate("alex", {"work": 8, "close": 3})
					Game.relate("mina", {"work": 5})
				await wait(1.0)
				if not is_current():
					return
				say("system", t("[RESOLVED] auth-service 정상화 · error rate 0.2%", "[RESOLVED] auth-service recovered · error rate 0.2%"), {"channel": "general"})
				await wait(1.5)
				if not is_current():
					return
				say("alex", t("로그인 정상화됐어요!! 정말 고마워요. 고객사에도 공지 나갔습니다.", "Logins are back!! Thank you so much. We've notified customers."))
				finish()
