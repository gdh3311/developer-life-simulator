extends "res://scripts/story/mission.gd"
## C05 M05 — who takes the night? A launch plan isn't done until the on-call rota is real:
## no one person on every window, nobody for twelve hours straight, Hana's leave respected.

const WINDOWS := ["eve", "night", "morning"]


func _init() -> void:
	id = "c05_05"
	chapter = 5
	day = 15
	issue = "NXR-065"
	title = t("누가 밤에 받나요", "Who takes the night?")
	objectives = [{"id": "rota", "app": "docs", "text": t("Docs에서 행사 운영표 제출 (시간대 담당·되돌리기 담당·지원 범위)", "Submit the campaign on-call rota in Docs (window owners, rollback owner, scope)")}]
	hints = [
		t("한 사람이 모든 칸을 맡으면 계획이 아니라 희망이에요. 오픈 관제와 밤 호출은 다른 사람이 받아요.", "One person on every window is a hope, not a plan. Launch watch and the night pager go to different people."),
		t("Hana는 목요일 오전 휴가예요. 되돌리기는 실제로 버튼을 누를 수 있는 사람이 맡아요.", "Hana is on leave Thursday morning. Rollback belongs to someone who can actually press the button."),
	]
	var people := {
		"me": t("나", "Me"), "daniel": t("Daniel", "Daniel"), "hana": t("Hana (SRE)", "Hana (SRE)"),
		"mina": t("Mina", "Mina"), "sophie": t("Sophie", "Sophie"), "alex": t("Alex (PM)", "Alex (PM)"),
	}
	var slot := func(slot_id: String, label: Dictionary, who: Array) -> Dictionary:
		return {"id": slot_id, "label": label, "inline": true, "options": who.map(func(w: String) -> Dictionary: return {"id": w, "text": people[w]})}
	forms_def = {"rota": {
		"title": t("봄 캠페인 운영표", "Spring campaign on-call rota"),
		"intro": t("수요일 20:00 오픈. Hana는 목요일 오전 휴가예요(반년 전에 잡아 둔 휴가). 모든 칸에 담당이 있어야 출시가 승인돼요.",
			"Opens Wednesday 20:00. Hana is on leave Thursday morning (booked six months ago). Launch is approved only when every slot has an owner."),
		"submit": t("Mina에게 보내기", "Send to Mina"),
		"slots": [
			slot.call("eve", t("수 20:00–22:00 오픈 관제", "Wed 20:00–22:00 launch watch"), ["me", "daniel", "hana", "mina"]),
			slot.call("night", t("수 22:00–목 08:00 호출 대기", "Wed 22:00–Thu 08:00 pager"), ["me", "daniel", "hana"]),
			slot.call("morning", t("목 08:00–10:00 조정 목록 확인", "Thu 08:00–10:00 reconciliation check"), ["me", "daniel", "hana", "sophie"]),
			slot.call("rollback", t("되돌리기 결정·실행", "Rollback call and execution"), ["me", "daniel", "hana", "alex"]),
			{"id": "scope", "label": t("지원 범위", "Support scope"), "options": [
				{"id": "campaign", "text": t("캠페인 상품·결제 흐름만 (나머지는 평소 당직)", "Campaign products and checkout only (everything else stays with the usual on-call)")},
				{"id": "everything", "text": t("서비스 전체를 이번 팀이 맡음", "This team covers the whole service")}]},
		],
	}}


func begin() -> void:
	Game.set_time(13 * 60 + 30)
	Game.add_issue(issue, title, "ops", Game.L("나", "me"), "progress")
	say("mina", t("출시 계획서 봤어요. 기능은 다 있는데 '누가 밤에 받나요?'가 비어 있어요. 운영표 없이는 승인 못 해요. Docs에 올려 뒀어요.",
		"I read the launch plan. All the features are there, but 'who takes the night?' is blank. I can't approve it without a rota. It's in Docs."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes: Array = []
	var who := {}
	for w in WINDOWS:
		who[w] = FormRules.picked(picks, w)[0]
	if WINDOWS.all(func(w: String) -> bool: return who[w] == "me"):
		notes.append(t("Mina: 혼자 모든 시간대를 맡으면 계획이 아니라 희망이에요. 밤 호출은 Hana나 Daniel과 나눠요. 다음 날 아침 조정 목록은 Sophie도 볼 수 있어요.",
			"Mina: Taking every window yourself is a hope, not a plan. Split the pager with Hana or Daniel; Sophie can read the morning reconciliation list too."))
	elif who["eve"] == who["night"]:
		notes.append(t("Hana: 오픈 관제부터 밤 호출까지 한 사람이면 열두 시간이에요. 새벽 세 시의 판단이 제일 나빠요.",
			"Hana: Launch watch through the night pager is twelve hours for one person. The 3 a.m. call is the worst call."))
	if who["morning"] == "hana":
		notes.append(t("Hana: 목요일 오전은 휴가예요. 반년 전에 잡았어요. 그 칸은 다른 사람이요.", "Hana: Thursday morning is my leave, booked six months ago. Someone else, please."))
	if FormRules.picked(picks, "rollback")[0] == "alex":
		notes.append(t("Alex: 되돌릴지 같이 판단은 할게요. 그런데 실제로 버튼을 누를 수 있는 사람이 담당이어야 해요.", "Alex: I'll help decide, but the owner has to be someone who can actually press the button."))
	if FormRules.picked(picks, "scope")[0] == "everything":
		notes.append(t("Hana: 서비스 전체를 이번 팀이 보면 캠페인 알림이 다른 알림에 묻혀요. 범위를 캠페인으로 좁혀요.", "Hana: If this team watches everything, campaign alerts drown in the rest. Narrow it to the campaign."))
	return notes


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var rota := {}
	var self_slots := 0
	for w in WINDOWS + ["rollback"]:
		rota[w] = FormRules.picked(picks, w)[0]
		if w in WINDOWS and rota[w] == "me":
			self_slots += 1
	Game.state["flags"]["c05_rota"] = rota
	Game.state["flags"]["c05_rota_self"] = self_slots
	complete("rota")
	Game.advance(30)
	if once("_reward"):
		Game.relate("mina", {"work": 3})
	if self_slots >= 2:
		say("mina", t("승인할게요. 다만 두 칸이 당신이에요. 목요일 오후는 쉬는 걸로 운영표에 같이 적었어요.", "Approved. Two windows are yours, though, so I've written Thursday afternoon off into the rota."))
	else:
		say("mina", t("승인. 이제 출시 계획에 사람이 들어갔네요.", "Approved. Now the launch plan has people in it."))
	say("hana", t("호출 받을 사람에게 되돌리기 절차 링크 보냈어요. 오늘 밤엔 다들 일찍 자요.", "I sent the rollback runbook to everyone on the pager. Everyone sleep early tonight."))
	doc_comment("rota", "hana", t("SRE 확인: 모든 시간대 담당 있음. 되돌리기 담당에게 절차 공유 완료.", "SRE: every window has an owner. Rollback runbook shared with the owner."))
	finish()
