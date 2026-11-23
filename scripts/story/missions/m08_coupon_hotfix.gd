extends "res://scripts/story/mission.gd"
## Day 3, 13:30 — Only if the coupon PR was approved with its bugs on day 2.


func _init() -> void:
	id = "m08"
	day = 3
	title = "쿠폰 결제 장애"
	issue = "#008"
	default_reviewer = "sophie"
	objectives = [
		{"id": "sync", "text": "최신 main 받기"},
		{"id": "tests", "text": "쿠폰 정책대로 수정 + 테스트 통과"},
		{"id": "pr", "text": "핫픽스 PR 만들기"},
		{"id": "ci", "text": "CI 통과"},
		{"id": "merged", "text": "PR 병합하기"},
	]
	hints = [
		"Wiki '쿠폰 정책'을 다시 읽어 보세요. 정률 쿠폰 value 는 퍼센트(0~100) 숫자입니다.",
		"할인액 = 정률이면 Math.floor(total * value / 100), 정액이면 value. 결제 금액은 Math.max(0, total - 할인액).",
	]


func should_run() -> bool:
	return Game.state["flags"].get("coupon_bug", false)


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue("#008", "[P1] 쿠폰 적용 시 결제 금액 0원 이하", "bug", "나", "progress")
	monitor("payments", "warn", "payments")
	await wait(1.0)
	say("mina", "10% 쿠폰을 쓴 주문의 결제 금액이 0원 이하로 찍혀요!! 어제 머지된 쿠폰 기능인 것 같아요. #008")
	Game.relate("alex", {"work": -3})
	await wait(2.0)
	say("sophie", "제 PR이에요... 리뷰 때 둘 다 놓쳤나 봐요 ㅠㅠ 같이 고쳐 주실 수 있나요?")


func hidden_tests() -> Dictionary:
	return load_tests("m08")


func review(p: Dictionary) -> void:
	CodeHub.review(p["id"], "sophie", "approved", "이번엔 정책이랑 하나하나 대조해 봤어요. 승인합니다!")


func on_event(kind: String, d: Dictionary) -> void:
	if kind == "pr_merged" and int(d["pr"]) == int(data().get("pr", 0)):
		monitor("payments", "ok", "normal")
		Game.relate("sophie", {"close": 5, "tech": 4})
		await wait(1.5)
		say("sophie", "고마워요! 앞으로 리뷰할 땐 정책 문서랑 대조하는 체크리스트를 써 볼게요.")
		finish()
