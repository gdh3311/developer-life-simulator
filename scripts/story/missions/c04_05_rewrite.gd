extends "res://scripts/story/mission.gd"
## C04 M05 — the afternoon you want to rewrite everything. A decision the real team can finish.

const TEAM := 2.0  # engineers available for ATLAS this quarter


func _init() -> void:
	id = "c04_05"
	chapter = 4
	day = 13
	issue = "NXR-055"
	title = t("전부 다시 만들고 싶은 오후", "The afternoon you want to rewrite everything")
	objectives = [{"id": "decision", "app": "docs", "text": t("Docs에서 ATLAS 범위 결정 문서 쓰기", "Write the ATLAS scope decision in Docs")}]
	hints = [t("이번 분기 ATLAS에 쓸 수 있는 인원은 2명이에요. 표어보다 그 인원으로 끝낼 수 있는지가 기준이에요.", "Two engineers are available for ATLAS this quarter. The bar is whether that team can finish it, not the slogan.")]
	forms_def = {"decision": {
		"title": t("ATLAS 1단계 결정", "ATLAS stage 1 decision"),
		"intro": t("세 가지 안을 실제 인원(2명)으로 비교해 하나를 고르고, 되돌리는 방법과 근거를 함께 적어요.", "Compare three options with the real team (two people), pick one, and add how to roll back and what supports it."),
		"submit": t("결정 문서 공유", "Share the decision"),
		"slots": [
			{"id": "scope", "label": t("범위", "Scope"), "options": [
				{"id": "rewrite", "text": t("전면 재작성 — 12주 · 3.5명 필요", "Full rewrite — 12 weeks · needs 3.5 people")},
				{"id": "phased", "text": t("단계별 교체 — 환불부터 4주 · 1.5명", "Phased — refunds first, 4 weeks · 1.5 people")},
				{"id": "status_quo", "text": t("현상 유지 — 0주 · 0명", "Status quo — 0 weeks · 0 people")}]},
			{"id": "rollback", "label": t("되돌리기", "Rollback"), "options": [
				{"id": "flag", "text": t("원장 읽기를 기능 플래그로 켜고, 차이가 기준을 넘으면 끈다", "Gate ledger reads behind a flag; turn it off if differences exceed the bar")},
				{"id": "none", "text": t("한 번에 전환하니 되돌릴 필요가 없다", "We switch in one go, so no rollback")}]},
			{"id": "evidence", "label": t("근거", "Evidence"), "multi": true, "max": 2, "options": [
				{"id": "bench", "text": t("환불 1만 건 이관 연습: 14분, 차이 0.3%", "Migration rehearsal on 10k refunds: 14 min, 0.3% differences")},
				{"id": "recon", "text": t("오늘 대조 보고서: 실제 누락 1건, 나머지는 규칙 차이", "Today's reconciliation: 1 real omission, the rest rule differences")},
				{"id": "feeling", "text": t("코드가 너무 낡아서 새로 짜는 게 빠를 것 같다", "The code feels too old; rewriting seems faster")}]},
		],
	}}


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue(issue, title, "decision", Game.L("나", "me"), "progress")
	say("system", t("일곱 번째 달 · 수요일", "Month seven · Wednesday"), {"channel": "general", "silent": true})
	say("sophie", t("솔직히 전부 새로 짜고 싶지 않아요? 저 환불 코드 보면 그런 마음이 들어요ㅋㅋ", "Honestly, don't you want to rewrite all of it? That refund code makes me want to lol"))
	say("alex", t("이번 분기 ATLAS에는 두 명이 붙을 수 있어요. 범위를 문서로 정해 주면 다른 팀 앞에서 설명할게요.", "Two people can work on ATLAS this quarter. Put the scope in a document and I'll present it to the other teams."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes: Array = []
	match FormRules.picked(picks, "scope")[0]:
		"rewrite":
			notes.append(t("Alex: 3.5명이 필요한데 우리는 2명이에요. 이 범위로는 분기 안에 못 끝내요.", "Alex: It needs 3.5 people and we have two. This scope can't finish this quarter."))
		"status_quo":
			if not "recon" in FormRules.picked(picks, "evidence"):
				notes.append(t("Daniel: 유지도 결정이에요. 다만 누락이 있었다는 근거를 보고도 유지하는 이유를 적어야 해요.", "Daniel: Keeping things is a decision too, but say why, given the evidence of an omission."))
	if FormRules.picked(picks, "rollback")[0] == "none":
		notes.append(t("Mina: 되돌릴 수 없는 전환은 틀렸을 때 고칠 시간이 없어요.", "Mina: A cutover you can't undo leaves no time to fix it when it's wrong."))
	if "feeling" in FormRules.picked(picks, "evidence"):
		notes.append(t("Daniel: 느낌은 근거가 아니에요. 이관 연습이나 대조 결과처럼 숫자로 보여 줘요.", "Daniel: A feeling isn't evidence. Show numbers, like the rehearsal or the reconciliation."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var scope: String = FormRules.picked(picks, "scope")[0]
	Game.state["flags"]["c04_scope"] = scope
	complete("decision")
	Game.advance(45)
	if once("_reward"):
		Game.relate("daniel", {"agree": 3, "tech": 2})
		Game.relate("alex", {"work": 3})
	if scope == "phased":
		say("daniel", t("환불부터 단계별로. 두 명이 실제로 끝낼 수 있는 범위네요. 이 문서, 제가 쓴 2023년 문서보다 낫네요.", "Refunds first, in stages. A scope two people can actually finish. This doc is better than the one I wrote in 2023."))
	else:
		say("daniel", t("유지라... 근거와 다음 확인 시점이 있으니 이해해요. 다만 계약 만료 전에는 다시 봐야 해요.", "Keeping it... with evidence and a next check, I understand. We'll revisit before the contract expires."))
	say("sophie", t("새로 짜고 싶은 마음은 접어 둘게요. 대신 환불 화면은 제가 맡을래요!", "I'll fold my rewrite dreams. But I call dibs on the refund screen!"), {"channel": "general"})
	finish()
