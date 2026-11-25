extends "res://scripts/story/mission.gd"
## C04 M07 — kindness that doesn't help. Daniel fixes every PR himself and drops other work.


func _init() -> void:
	id = "c04_07"
	chapter = 4
	day = 13
	issue = "NXR-057"
	title = t("도와주지 않는 친절", "Kindness that doesn't help")
	objectives = [{"id": "rotation", "app": "docs", "text": t("Docs에서 리뷰 분담 방법 두 가지 정하기", "Pick two ways to share reviews in Docs")}]
	forms_def = {"rotation": {
		"title": t("리뷰 분담표", "Review rotation"),
		"intro": t("Daniel 앞에 리뷰 대기 PR이 11개예요. 그는 대부분을 직접 고쳐서 다시 올려요. 두 가지를 골라 팀에 제안해요.",
			"Daniel has 11 PRs waiting. He rewrites most of them himself. Pick two changes to propose to the team."),
		"submit": t("팀에 제안", "Propose to the team"),
		"slots": [{"id": "fix", "label": t("방법", "Changes"), "multi": true, "max": 2, "options": [
			{"id": "slots", "text": t("리뷰 시간을 하루 두 번 예약해 몰아서 본다", "Book two review slots a day and batch reviews")},
			{"id": "train", "text": t("다른 사람도 검토할 수 있게 체크리스트와 짝 리뷰를 시작한다", "Start a checklist and pair reviews so others can review too")},
			{"id": "small", "text": t("PR을 400줄 이하로 쪼갠다", "Keep PRs under 400 lines")},
			{"id": "harder", "text": t("Daniel이 조금 더 서두르면 된다", "Daniel just needs to go a bit faster")}]}],
	}}


func begin() -> void:
	Game.set_time(14 * 60)
	Game.add_issue(issue, title, "team", Game.L("나", "me"), "progress")
	say("mina", t("Daniel 리뷰 대기가 11개예요. 어제 새벽 1시에 제 PR을 직접 고쳐서 올렸더라고요. 고맙긴 한데... 이러다 쓰러지겠어요.",
		"Daniel has 11 reviews queued. He rewrote my PR himself at 1 AM yesterday. I'm grateful, but... he'll burn out."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	if FormRules.picked(picks, "fix").size() < 2:
		return [t("두 가지를 골라 주세요.", "Pick two.")]
	return []


func on_form_accepted(_form_id: String, picks: Dictionary) -> void:
	var fix := FormRules.picked(picks, "fix")
	Game.state["flags"]["c04_review_fix"] = fix
	complete("rotation")
	if "harder" in fix:
		Game.state["flags"]["daniel_tired"] = true
		Game.relate("daniel", {"close": -2})
		say("daniel", t("...알겠어요. 더 빨리 볼게요.", "...Okay. I'll go faster."))
		say("mina", t("이번 주는 빨라지겠지만, 다음 주엔 Daniel이 없을지도 몰라요.", "It'll be faster this week, but next week we might not have a Daniel."), {"channel": "general"})
	else:
		Game.relate("daniel", {"close": 3, "agree": 2})
		say("daniel", t("제가 다 고치는 게 친절이라고 생각했는데, 결국 제가 병목이었네요.", "I thought fixing everything myself was kindness, but I became the bottleneck."))
	if "slots" in fix:
		say("daniel", t("리뷰는 11시와 4시에 몰아서 볼게요. 캘린더에 넣었어요. 그 사이엔 제 일을 할게요.", "I'll review at 11 and 4 and put both on the calendar. In between I'll do my own work."))
	if "small" in fix:
		say("mina", t("400줄 넘는 PR엔 쪼개 달라고 코멘트 달게요. 제 PR부터요ㅎㅎ", "I'll ask for splits on PRs over 400 lines. Starting with mine, ha."), {"channel": "general"})
	if "train" in fix:
		say("daniel", t("체크리스트는 오늘 올릴게요. 짝 리뷰 첫 짝은 당신이 해 줄래요?", "I'll post the checklist today. Will you be my first pair reviewer?"))
	if "train" in fix:
		Game.state["flags"]["mentoring_started"] = true
	finish()
