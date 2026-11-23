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
		{"id": "branch", "app": "terminal",
			"text": t("작업 브랜치 만들기", "Create a working branch"),
			"guide": t("main에서 바로 고치지 않아요. 작업용 브랜치를 만들어요:\n  git switch -c docs/fix-typo",
				"We never change main directly. Create a branch for the work:\n  git switch -c docs/fix-typo")},
		{"id": "edit", "app": "ide",
			"text": t("DevIDE에서 README.md 오타(Commerse → Commerce) 고치고 저장", "Fix the typo in README.md (Commerse → Commerce) in DevIDE and save"),
			"guide": t("코드 아이콘(DevIDE) → 왼쪽 파일 목록에서 README.md → 'Commerse'를 'Commerce'로 고치고 Ctrl+S 로 저장.",
				"Code icon (DevIDE) → README.md in the file tree → change 'Commerse' to 'Commerce' and press Ctrl+S.")},
		{"id": "diff", "app": "terminal",
			"text": t("git diff 로 바뀐 내용 확인", "Review the change with git diff"),
			"guide": t("커밋하기 전에 무엇이 바뀌었는지 꼭 확인해요:\n  git diff\n- 로 시작하는 줄은 지워진 것, + 는 추가된 것이에요.",
				"Always check what changed before committing:\n  git diff\nLines starting with - were removed, + were added.")},
		{"id": "commit", "app": "terminal",
			"text": t("변경 사항 커밋하기", "Commit the change"),
			"guide": t("커밋할 파일을 고르고(add), 메시지와 함께 저장(commit)해요:\n  git add README.md\n  git commit -m \"docs: fix typo in README\"",
				"Stage the file (add), then record it with a message (commit):\n  git add README.md\n  git commit -m \"docs: fix typo in README\"")},
		{"id": "push", "app": "terminal",
			"text": t("브랜치를 원격 저장소로 push", "Push the branch to the remote"),
			"guide": t("내 컴퓨터의 커밋을 회사 원격 저장소로 올려요:\n  git push",
				"Upload your commits to the company remote:\n  git push")},
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


func begin() -> void:
	Game.set_time(10 * 60)
	Game.add_issue("#000", Game.LL("README 오타 수정 (온보딩)", "Fix README typo (onboarding)"), "docs", Game.L("나", "me"), "progress")
	await wait(1.5)
	if not is_current():
		return
	say("daniel", t("안녕하세요, 백엔드 시니어 Daniel입니다. 첫 업무로 가볍게 가죠. README에 'Commerse'라는 오타가 있어요. 고쳐서 PR로 올려 주세요. 오른쪽 아래 가이드대로 하면 됩니다.",
		"Hi, I'm Daniel, senior backend. Let's start light: the README has a typo, 'Commerse'. Fix it and send a PR. Follow the guide at the bottom left."))


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
