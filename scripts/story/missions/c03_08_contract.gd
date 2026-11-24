extends "res://scripts/story/mission.gd"
## C03 M08 — the first contract. Bring real records to the review; the result is a promotion or a
## concrete improvement plan, and the story continues either way. Ends with the launch notice.

## Average team trust needed to move up from each rank at this review.
const PROMOTE_AT := {0: 18.0, 1: 24.0}


func _init() -> void:
	id = "c03_08"
	chapter = 3
	day = 10
	issue = "NXR-048"
	title = t("첫 번째 계약서", "The first contract")
	objectives = [
		{"id": "records", "app": "docs", "text": t("Docs에서 평가 면담에 가져갈 기록 고르기", "Choose the records you bring to the review in Docs")},
		{"id": "result", "text": t("면담 결과 듣기", "Hear the result")},
	]
	hints = [
		t("기록으로 확인할 수 있는 일을 고르세요. 노력만 적은 항목은 면담에서 근거가 되지 않아요.", "Pick work that records can confirm. Effort alone isn't evidence in a review."),
	]
	forms_def = {
		"review": {
			"title": t("평가 면담 준비", "Review preparation"),
			"intro": t("Alex와 Daniel이 함께하는 면담이에요. 실제로 한 일 중 2~3개를 골라 가져가고, 다음 목표를 정합니다.",
				"Alex and Daniel run the review together. Bring two or three things you actually did, and pick your next goal."),
			"submit": t("면담 들어가기", "Go to the review"),
			"slots": [
				{"id": "records", "label": t("가져갈 기록", "Records to bring"), "multi": true, "max": 3, "options": []},
				{"id": "goal", "label": t("다음 6개월 목표", "Goal for the next six months"), "options": [
					{"id": "depth", "text": t("주문·결제 흐름을 깊게 이해하고 설명할 수 있게 되기", "Understand the order/payment flow deeply enough to explain it")},
					{"id": "product", "text": t("고객 문제 하나를 처음부터 끝까지 맡는 일을 늘리기", "Own more customer problems end to end")},
					{"id": "people", "text": t("리뷰와 문서로 동료가 덜 막히게 돕기", "Help teammates get unstuck through reviews and docs")}]},
			],
		},
	}


func _records() -> Array:
	var r: Array = []
	if Story.status("c02_08") == "done":
		r.append({"id": "c02_dup", "ok": true, "text": t("달빛상점 중복 주문: 재현 → 순차·동시 계약 → 제한 적용 → 고객 답장 (NXR-021~028)", "Moonlight duplicate orders: reproduce → sequential & concurrent contract → limited rollout → customer reply (NXR-021–028)")})
	if Game.state["flags"].get("c02_log_policy", false):
		r.append({"id": "c02_log", "ok": true, "text": t("주문 로그에서 구매자 정보를 빼고 허용 목록으로 바꿈", "Switched order logs to an allowlist, removing buyer data")})
	var c205 = Story.mission("c02_05")
	if c205 != null and Game.state["story"].has("c02_05") and c205.data().get("found_by", "") == "me":
		r.append({"id": "c02_review", "ok": true, "text": t("Sophie PR 리뷰에서 timeout을 실패로 보여 주는 문제 발견", "Caught the timeout-shown-as-failure bug in Sophie's PR review")})
	r.append({"id": "c03_preorder", "ok": true, "text": t("예약 판매 v1: 6일 범위 조정 → 마감·취소·문구 → 베타 → 출시", "Pre-order v1: six-day scope → deadline, cancel, wording → beta → launch")})
	r.append({"id": "c03_owner", "ok": true, "text": t("출시 후 담당·공용 채널·운영 설명서 정리", "Set post-launch ownership, shared channel and runbook")})
	if Game.state["flags"].get("l17_pattern", false):
		r.append({"id": "l17", "ok": true, "text": t("LEGACY-17 감사 로그에서 재결제 불일치 패턴 확인 (업무 외)", "Found the re-payment mismatch pattern in the LEGACY-17 audit log (side work)")})
	r.append({"id": "effort", "ok": false, "text": t("매일 늦게까지 남아 열심히 일함", "Stayed late every day and worked hard")})
	return r


func open_forms() -> Array:
	forms_def["review"]["slots"][0]["options"] = _records().map(func(x: Dictionary) -> Dictionary: return {"id": x["id"], "text": x["text"]})
	return super.open_forms()


func submit_form(form_id: String, picks: Dictionary) -> Array:
	forms_def["review"]["slots"][0]["options"] = _records().map(func(x: Dictionary) -> Dictionary: return {"id": x["id"], "text": x["text"]})
	return super.submit_form(form_id, picks)


func begin() -> void:
	Game.set_time(16 * 60 + 30)
	Game.add_issue(issue, title, "career", Game.L("나", "me"), "progress")
	say("alex", t("면담 시간이에요. 거창하게 준비할 건 없고, 지난 몇 달 동안 한 일 중 이야기하고 싶은 걸 2~3개만 Docs에 골라 와요.",
		"Review time. Nothing grand: pick two or three things from the last few months you'd like to talk about, in Docs."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var chosen := FormRules.picked(picks, "records")
	if "effort" in chosen:
		return [t("Daniel: 늦게까지 남은 건 고마워요. 그런데 그건 결과의 근거가 아니라 비용이에요. 기록으로 보여 줄 수 있는 일을 골라요.",
			"Daniel: Thanks for staying late, but that's a cost, not evidence of results. Pick work the records can show.")]
	if chosen.size() < 2:
		return [t("기록을 두 개 이상 골라 주세요.", "Pick at least two records.")]
	return []


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	complete("records")
	Game.advance(40)
	var rank := int(Game.state["rank"])
	var avg := Game.avg_trust()
	var promoted := PROMOTE_AT.has(rank) and avg >= float(PROMOTE_AT[rank])
	Game.state["flags"]["c03_goal"] = FormRules.picked(picks, "goal")[0]
	Game.state["flags"]["c03_review"] = {"promoted": promoted, "avg": roundi(avg), "rank_before": rank, "records": FormRules.picked(picks, "records")}
	if promoted:
		Game.state["rank"] = rank + 1
		Game.emit_event("promoted", {"rank": rank + 1})
		say("alex", t("결론부터 말할게요. %s로 올라가요. 기록이 구체적이라 우리도 설명하기 쉬웠어요." % Game.rank_name(),
			"Bottom line first: you're moving up to %s. Your records were concrete, which made it easy for us to justify." % Game.rank_name()))
	else:
		say("alex", t("이번엔 직급은 그대로예요. 대신 다음 평가는 두 달 뒤로 잡고, Daniel이 매주 30분씩 같이 볼게요. 무엇을 보면 되는지도 적어 뒀어요.",
			"Your level stays the same this time. The next review is in two months, and Daniel will pair with you 30 minutes a week. We wrote down exactly what we'll look for."))
		Game.state["flags"]["c03_growth_plan"] = true
	say("daniel", t("고른 기록이 다 '무엇을 확인했는지'로 설명되더라고요. 그게 제일 좋았어요.", "Every record you picked was explained by what you verified. That was the best part."))
	complete("result")
	_launch_notice()


func _launch_notice() -> void:
	await wait(2.0)
	if not is_current():
		return
	Game.set_time(18 * 60)
	var owner := String(Game.state["flags"].get("c03_owner", "me"))
	var names := Game.pname() + (" · Sophie Lee" if owner == "pair" else "")
	say("alex", t("📣 예약 판매 v1 정식 출시 — 담당: %s. 판매자 현지 시각 마감, 취소·환불 요청 분리, 발송 예정일 표시." % names,
		"📣 Pre-order v1 is live — owner: %s. Seller-local deadlines, separate cancel and refund requests, ship-by dates." % names), {"channel": "general"})
	await wait(2.0)
	if not is_current():
		return
	say("yuri", t("모자이크 마켓 판매자 댓글이 달렸어요: “좋네요. 그런데 이 기능은 누가 유지하나요?”\n→ #preorder에 담당과 문의 시간이 있어서 바로 링크로 답했어요.",
		"A Mosaic Market seller commented: “Nice. But who maintains this feature?”\n→ #preorder lists the owner and hours, so I answered with a link."), {"channel": "general"})
	await wait(1.5)
	if is_current():
		finish()
