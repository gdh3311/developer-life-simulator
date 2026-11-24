extends "res://scripts/story/mission.gd"
## Day 1, ~10:00 — Tutorial: first PR (README typo). Branch, edit, diff, commit, push, PR.
## Interns can't merge: Daniel reviews and merges.


func _init() -> void:
	id = "d1_02"
	day = 1
	tutorial = true
	title = t("첫 PR: README 오타 수정", "First PR: fix a README typo")
	issue = "#000"
	objectives = [
		{"id": "branch", "app": "terminal", "alternative": "pork",
			"text": t("작업 브랜치 만들기", "Create a working branch"),
			"guide": t("Pork Git에서 새 브랜치에 docs/fix-typo를 입력하거나 터미널에서 실행하세요.\n  git switch -c docs/fix-typo",
				"Enter docs/fix-typo in Pork Git and click New branch, or run this in Terminal:\n  git switch -c docs/fix-typo")},
		{"id": "edit", "app": "ide",
			"text": t("DevIDE에서 README.md 오타(Commerse → Commerce) 고치고 저장", "Fix the typo in README.md (Commerse → Commerce) in DevIDE and save"),
			"guide": t("코드 아이콘(DevIDE) → 왼쪽 파일 목록에서 README.md → 'Commerse'를 'Commerce'로 고치고 Ctrl+S 로 저장.",
				"Code icon (DevIDE) → README.md in the file tree → change 'Commerse' to 'Commerce' and press Ctrl+S.")},
		{"id": "diff", "app": "terminal", "alternative": "pork",
			"text": t("README에서 바뀐 줄 확인", "Review the changed lines in README"),
			"guide": t("Pork Git의 변경 파일에서 README.md를 고르거나 터미널에서 확인하세요. -는 제거한 줄, +는 추가한 줄입니다.\n  git diff",
				"Select README.md in Pork Git's Changes tab, or use Terminal. Lines with - were removed and lines with + were added.\n  git diff")},
		{"id": "commit", "app": "terminal", "alternative": "pork",
			"text": t("변경 사항 커밋하기", "Commit the change"),
			"guide": t("Pork Git에서 파일을 스테이징하고 메시지를 적어 커밋하세요. 터미널을 쓸 수도 있어요.\n  git add README.md\n  git commit -m \"docs: fix typo in README\"",
				"Stage the file in Pork Git and commit it with a message, or use Terminal:\n  git add README.md\n  git commit -m \"docs: fix typo in README\"")},
		{"id": "push", "app": "terminal", "alternative": "pork",
			"text": t("브랜치를 원격 저장소로 push", "Push the branch to the remote"),
			"guide": t("Pork Git에서 Push를 누르거나 터미널 명령으로 커밋을 회사 저장소에 올리세요.\n  git push",
				"Upload your commit to the company remote with Push in Pork Git or with Terminal:\n  git push")},
		{"id": "pr", "app": "codehub",
			"text": t("CodeHub에서 Pull Request 만들기 (설명도 적기)", "Open a Pull Request in CodeHub (with a description)"),
			"guide": t("PR 아이콘(CodeHub) → '새 Pull Request' → 브랜치 선택 → 제목과 설명을 적고 'PR 만들기'.",
				"PR icon (CodeHub) → 'New Pull Request' → pick your branch → write a title and description → 'Create PR'.")},
		{"id": "merged", "app": "codehub",
			"text": t("Daniel의 리뷰와 병합 기다리기", "Wait for Daniel to review and merge"),
			"guide": t("인턴은 직접 병합할 수 없어요. CI가 통과하면 Daniel이 리뷰하고 병합해 줘요. CodeHub에서 진행 상황을 볼 수 있어요.",
				"Interns can't merge. Once CI passes, Daniel reviews and merges it. Watch the progress in CodeHub.")},
	]
	hints = [
		t("순서: git switch -c docs/fix-typo → DevIDE에서 README.md 수정·저장 → git diff → git add README.md → git commit -m \"docs: ...\" → git push → CodeHub에서 PR",
			"Order: git switch -c docs/fix-typo → edit and save README.md in DevIDE → git diff → git add README.md → git commit -m \"docs: ...\" → git push → open a PR in CodeHub"),
	]
	ai_task = {
		"label": t("README의 제품명 수정", "Correct the product name in README"),
		"substitution": {"path": "README.md", "from": "NEXORA Commerse Cloud", "to": "NEXORA Commerce Cloud"},
		"summary": t("README 제품명 한 곳을 고쳤습니다.", "Corrected one occurrence of the product name in README."),
		"minutes": 5,
	}


func begin() -> void:
	Game.set_time(10 * 60)
	Game.add_issue("#000", Game.LL("README 오타 수정 (온보딩)", "Fix README typo (onboarding)"), "docs", Game.L("나", "me"), "progress")
	await wait(1.5)
	if not is_current():
		return
	say("daniel", t("백엔드 시니어 Daniel입니다. 커머스팀 새 입사자들이 저장소를 열면 README부터 읽어요. 거기 제품명이 'Commerse'로 적혀 있더라고요. 'Commerce'로 고쳐서 PR 올려 주세요. 오늘 제가 리뷰할게요.",
		"I'm Daniel, the senior backend engineer. New people on the commerce team start with the README. It spells the product name 'Commerse'. Change it to 'Commerce', send me a PR, and I'll review it today."))
	say("daniel", t("아까 터미널에서 기록을 봤죠? 바뀐 파일을 하나씩 확인할 때마다 명령어를 치면 번거롭지 않아요? 저는 그럴 땐 Pork Git을 켜요. README를 저장하고 왼쪽에서 파일을 고르면 바뀐 줄이 보여요. 여기서 브랜치 만들고 커밋, push까지 할 수 있어요.",
		"You checked the history in Terminal earlier, right? Repeating commands gets tedious when you're looking through several files. I open Pork Git for that. Save the README, pick it on the left, and you'll see which lines changed. You can also create the branch, commit and push from there."),
		{"link": {"app": "pork", "label": t("Pork Git 열기", "Open Pork Git")}})


func review(p: Dictionary) -> void:
	var readme := await Workspace._git_in(Workspace.origin, ["show", "refs/heads/" + p["branch"] + ":README.md"])
	if not is_current():
		return
	if readme["code"] != 0 or "Commerse" in String(readme["out"]) or not "Commerce" in String(readme["out"]):
		CodeHub.review(p["id"], "daniel", "changes", t("README의 Commerse → Commerce 수정이 아직 반영되지 않았어요. DevIDE에서 고쳐 저장하고 새 커밋을 push해 주세요.", "The README typo fix (Commerse → Commerce) is still missing. Save it in DevIDE and push another commit."))
		return
	complete("edit")
	var commits := await Workspace.pr_commits(p["branch"])
	if not is_current():
		return
	var conventional := commits.any(func(c: String) -> bool:
		var subject := c.get_slice("|", 2)
		return subject.begins_with("docs") or subject.begins_with("fix") or subject.begins_with("chore"))
	var notes_ko := "오타 수정 확인했습니다. 첫 PR 축하해요."
	var notes_en := "Typo fix confirmed. Congrats on your first PR."
	if p["flags"].get("no_body", false):
		notes_ko += " 다음부터는 PR 설명도 꼭 적어 주세요. 리뷰어가 맥락을 알 수 있게요."
		notes_en += " Next time, add a PR description so reviewers get the context."
		Game.relate("daniel", {"work": -2})
	if not conventional:
		notes_ko += " 커밋 메시지는 'docs: ...', 'fix: ...' 처럼 종류를 앞에 붙이는 게 팀 규칙이에요."
		notes_en += " Our convention is to prefix commit messages, like 'docs: ...' or 'fix: ...'."
		Game.relate("daniel", {"agree": -2})
	else:
		Game.relate("daniel", {"work": 3})
	CodeHub.review(p["id"], "daniel", "approved", t(notes_ko, notes_en))


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"file_saved", "command_finished":
			if not is_done("edit"):
				var readme := Workspace.read_file("README.md")
				if not "Commerse" in readme and "Commerce" in readme:
					complete("edit")
			if kind == "command_finished" and int(d.get("code", -1)) == 0 and is_git(d["argv"], "diff"):
				complete("diff")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				await wait(1.5)
				if not is_current():
					return
				say("sophie", t("첫 PR 병합 축하해요!! 이제 진짜 NEXORA 개발자네요 :)", "Congrats on your first merged PR!! You're officially a NEXORA developer :)"))
				if once("_merge_reward"):
					Game.relate("sophie", {"close": 2})
				finish()
