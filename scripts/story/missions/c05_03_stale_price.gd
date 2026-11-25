extends "res://scripts/story/mission.gd"
## C05 M03 — the faster, older value. A cached price is fine for browsing, never for the amount
## charged. Invalidate only the changed product; hidden CI checks the TTL and the narrow invalidation.


func _init() -> void:
	id = "c05_03"
	chapter = 5
	day = 14
	issue = "NXR-063"
	title = t("빨라진 오래된 값", "The faster, older value")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 가격 캐시 받기", "Update main to get the price cache")},
		{"id": "pricefix", "text": t("가격 변경 직후에도 맞는 금액으로 결제되게 고치고 테스트 통과", "Charge the right amount right after a price change; pass the tests")},
		{"id": "pr", "text": t("수정 PR 만들기", "Open the fix PR")},
		{"id": "ci", "text": t("추가 CI 검증 통과", "Pass the additional CI checks")},
		{"id": "merged", "text": t("검토와 병합", "Review and merge")},
	]
	hints = [
		t("Wiki '캠페인 준비 > 가격 캐시'를 보세요. 조회 속도와 결제 정확도는 다른 지표예요.", "See Wiki 'Campaign prep > Price cache'. Lookup speed and checkout accuracy are different metrics."),
		t("update()에서 그 상품의 캐시만 지우고, checkoutPrice()는 source.get()을 직접 읽어요. cache.clear()는 다른 상품까지 식혀요.", "In update(), delete only that product's entry; checkoutPrice() reads source.get() directly. cache.clear() cools every other product too."),
	]


func begin() -> void:
	Game.set_time(15 * 60)
	Game.add_issue(issue, title, "bug", Game.L("나", "me"), "progress")
	if not data().get("_prepared", false):
		await Workspace.bot_commit("sophie", "main", {
			"src/pricing/price_cache.ts": Workspace.content("c05/price_cache.ts"),
			"tests/price_cache.test.ts": Workspace.content("c05/price_cache.test.ts"),
		}, "feat(pricing): 60s price cache for the campaign pages")
		if not is_current():
			return
		data()["_prepared"] = true
	say("sophie", t("상품 페이지가 너무 느려서 가격에 60초 캐시를 붙였어요. 빨라지긴 했는데... 리허설에서 가격을 고친 직후 1분 동안 옛날 가격으로 결제됐대요.",
		"The product page was slow, so I put a 60-second cache on prices. It's faster... but in rehearsal, for a minute after a price fix, people were charged the old price."))
	say("alex", t("마케팅이 오픈 직후 가격을 한 번 고칠 수도 있대요. 화면이 1분 늦는 건 괜찮지만, 결제 금액이 틀리면 환불 건이에요.",
		"Marketing might correct the price right after opening. A page a minute behind is fine; a wrong charge is a refund case."))


func hidden_tests() -> Dictionary:
	return load_tests("c05_03")


func review(p: Dictionary) -> void:
	CodeHub.review(p["id"], "sophie", "approved", t("화면은 계속 빠르고 결제 금액은 항상 원본이네요. 다른 상품 캐시도 그대로고요. 고마워요!",
		"Pages stay fast and the charge always reads the source. Other products keep their cache too. Thank you!"))


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			if d.get("ok", false) and FileAccess.file_exists(Workspace.resolve("tests/price_cache.test.ts")):
				complete("pricefix")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if once("_merge_reward"):
					Game.relate("sophie", {"tech": 2, "close": 2})
				await wait(1.0)
				if not is_current():
					return
				say("sophie", t("속도는 화면 지표, 정확도는 주문 지표. 대시보드도 둘로 나눠 둘게요.", "Speed is a page metric, accuracy is an order metric. I'll split the dashboard in two as well."))
				finish()
