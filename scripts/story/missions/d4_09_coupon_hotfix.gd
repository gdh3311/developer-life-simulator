extends "res://scripts/story/mission.gd"
## Day 4, 13:30 — Only if the coupon bugs slipped through review on day 3.


func _init() -> void:
	id = "d4_09"
	day = 4
	title = t("쿠폰 결제 장애", "Coupon payment incident")
	issue = "#008"
	default_reviewer = "mina"
	objectives = [
		{"id": "sync", "text": t("최신 main 받기", "Get the latest main")},
		{"id": "tests", "text": t("쿠폰 정책대로 수정 + 테스트 통과", "Fix per the coupon policy + pass tests")},
		{"id": "pr", "text": t("핫픽스 PR 만들기", "Open a hotfix PR")},
		{"id": "ci", "text": t("CI 통과", "CI passes")},
		{"id": "merged", "text": t("병합", "Merged")},
	]
	hints = [
		t("Wiki '쿠폰 정책'을 다시 읽어 보세요. 정률 쿠폰 value 는 퍼센트(0~100) 숫자입니다.", "Re-read the Wiki 'Coupon policy'. A percent coupon's value is a percentage (0-100)."),
		t("할인액 = 정률이면 Math.floor(total * value / 100), 정액이면 value. 결제 금액은 Math.max(0, total - 할인액).", "discount = percent ? Math.floor(total * value / 100) : value. charge = Math.max(0, total - discount)."),
	]


func should_run() -> bool:
	return Game.state["flags"].get("coupon_bug", false)


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue("#008", Game.LL("[P1] 쿠폰 적용 시 결제 금액 0원 이하", "[P1] Coupon orders charge zero or less"), "bug", Game.L("나", "me"), "progress")
	monitor("payments", "warn", "payments")
	await wait(1.0)
	if not is_current():
		return
	say("mina", t("10% 쿠폰을 쓴 주문의 결제 금액이 0원 이하로 찍혀요!! 어제 머지된 쿠폰 기능 같아요. #008", "Orders with a 10% coupon are charging zero or less!! Probably yesterday's coupon feature. #008"))
	Game.relate("alex", {"work": -4})
	Game.relate("daniel", {"tech": -3})
	await wait(2.0)
	if not is_current():
		return
	say("sophie", t("제 PR이에요... 리뷰 때 다들 놓쳤나 봐요 ㅠㅠ 같이 고쳐 주실 수 있나요?", "That's my PR... we all missed it in review :( Can you help fix it?"))


func hidden_tests() -> Dictionary:
	return load_tests("m08")


func review(p: Dictionary) -> void:
	CodeHub.review(p["id"], "mina", "approved", t("이번엔 정책이랑 하나하나 대조해 봤어요. 승인합니다!", "I checked it against the policy line by line this time. Approved!"))


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "pr_merged" and int(d["pr"]) == int(data().get("pr", 0)):
		monitor("payments", "ok", "normal")
		if once("_merge_reward"):
			Game.relate("sophie", {"close": 5, "tech": 4})
		await wait(1.5)
		if not is_current():
			return
		say("sophie", t("고마워요! 앞으로 리뷰할 땐 정책 문서랑 대조하는 체크리스트를 써 볼게요.", "Thank you! I'll use a checklist against the policy docs when reviewing from now on."))
		finish()
