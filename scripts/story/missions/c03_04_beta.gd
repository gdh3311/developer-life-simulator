extends "res://scripts/story/mission.gd"
## C03 M04 — a very small beta. Choosing only the friendliest customer hides other usage patterns.


func _init() -> void:
	id = "c03_04"
	chapter = 3
	day = 9
	issue = "NXR-044"
	title = t("아주 작은 베타", "A very small beta")
	objectives = [
		{"id": "beta", "app": "docs", "text": t("Docs에서 베타 고객과 끄는 조건 정하기", "Choose beta customers and the switch-off rule in Docs")},
	]
	hints = [
		t("가장 친한 고객은 피드백이 빠르지만, 우리가 모르는 사용 방식은 다른 고객에게 있어요.", "The friendliest customer answers fast, but usage patterns we don't know live with other customers."),
		t("끄는 조건은 숫자로 확인할 수 있어야 해요.", "The switch-off rule has to be checkable with a number."),
	]
	forms_def = {
		"beta": {
			"title": t("예약 판매 베타 계획", "Pre-order beta plan"),
			"intro": t("기능 플래그로 1~2곳에만 먼저 켭니다. 고객마다 쓰는 방식이 달라요.", "We turn the feature flag on for one or two customers first. Each uses the product differently."),
			"submit": t("플래그 계획 확정", "Confirm the flag plan"),
			"slots": [
				{"id": "targets", "label": t("베타 고객", "Beta customers"), "multi": true, "max": 2, "options": [
					{"id": "moonlight", "text": t("달빛상점 — 작은 판매자, 우리와 가장 친하고 답이 빠름", "Moonlight — small seller, our closest customer, replies fast")},
					{"id": "aurora", "text": t("오로라 리테일 — 주문 규모가 크고 같은 시간대", "Aurora Retail — high order volume, same time zone")},
					{"id": "mosaic", "text": t("모자이크 마켓 — 여러 판매자 모음, 해외(UTC+7) 판매자 포함", "Mosaic Market — many sellers, including overseas sellers (UTC+7)")}]},
				{"id": "off", "label": t("플래그를 끄는 조건", "When we switch the flag off"), "options": [
					{"id": "metric", "text": t("마감 이후 주문 생성 1건 이상, 또는 환불 누락 1건 이상", "Any order created after a deadline, or any missing refund")},
					{"id": "feel", "text": t("문제가 커 보이면 그때 판단", "Decide if things look bad")}]},
			],
		},
	}


func begin() -> void:
	Game.set_time(13 * 60)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	say("alex", t("베타는 어디로 할까요? 달빛상점은 바로 써 보겠다고 하던데요!", "Where do we run the beta? Moonlight says they'll try it right away!"))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	if FormRules.picked(picks, "off")[0] == "feel":
		return [t("Mina: '커 보이면'은 사람마다 달라요. 몇 건이면 끄는지 정해 두면 밤에 혼자 고민 안 해도 돼요.", "Mina: 'Looks bad' differs per person. Agree on a number so nobody agonizes alone at night.")]
	return []


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var targets := FormRules.picked(picks, "targets")
	Game.state["flags"]["c03_beta"] = targets
	Game.state["flags"]["c03_beta_diverse"] = "mosaic" in targets
	complete("beta")
	monitor("api", "ok", "normal")
	if "mosaic" in targets:
		Game.relate("mina", {"work": 2})
		say("mina", t("모자이크 마켓이면 해외 판매자 마감도 같이 볼 수 있겠네요. 좋아요.", "With Mosaic we'll see overseas deadlines too. Nice."))
	else:
		say("daniel", t("빠른 피드백은 받겠네요. 다만 해외 판매자 같은 사용 방식은 이번 베타에서 안 보일 거예요.", "You'll get fast feedback. Just know usage like overseas sellers won't show up in this beta."))
	say("alex", t("플래그 켰어요! 베타 판매자들에게 안내 보낼게요.", "Flag's on! I'll notify the beta sellers."))
	finish()
