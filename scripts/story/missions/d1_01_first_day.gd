extends "res://scripts/story/mission.gd"
## Day 1, 09:00 — Tutorial: chat, wiki, terminal basics, git identity, reading history.


func _init() -> void:
	id = "d1_01"
	day = 1
	tutorial = true
	title = t("첫 출근: 업무 환경 익히기", "First day: learn your workstation")
	objectives = [
		{"id": "hello", "app": "chat",
			"text": t("TeamChat에서 Alex에게 인사하기", "Say hi to Alex in TeamChat"),
			"guide": t("화면 아래 독에서 말풍선 아이콘(TeamChat)을 누르고, Alex의 메시지 아래 답장 버튼을 고르세요.",
				"Click the speech-bubble icon (TeamChat) in the dock, then pick a reply under Alex's message.")},
		{"id": "wiki", "app": "wiki",
			"text": t("Wiki에서 '온보딩 가이드' 읽기", "Read the 'Onboarding guide' in the Wiki"),
			"guide": t("책 아이콘(Wiki)을 열고 왼쪽 목록에서 '온보딩 가이드'를 누르세요. 앞으로 하는 일의 흐름이 정리되어 있어요.",
				"Open the book icon (Wiki) and click 'Onboarding guide' on the left. It describes how work flows here.")},
		{"id": "help", "app": "terminal",
			"text": t("Terminal을 열고 help 입력하기", "Open the Terminal and type help"),
			"guide": t("검은 화면 아이콘(Terminal)을 열고 help 를 입력한 뒤 Enter. 쓸 수 있는 명령이 나와요.",
				"Open the dark-screen icon (Terminal), type help and press Enter. It lists the commands you can use.")},
		{"id": "explore", "app": "terminal",
			"text": t("ls 와 cat README.md 로 저장소 둘러보기", "Look around with ls and cat README.md"),
			"guide": t("ls 는 파일 목록, cat 은 파일 내용을 보여줘요. ls 를 입력한 다음 cat README.md 를 입력해 보세요.",
				"ls lists files and cat prints a file. Type ls, then cat README.md.")},
		{"id": "identity", "app": "terminal",
			"text": t("git config 로 내 이름과 이메일 설정하기", "Set your name and email with git config"),
			"guide": t("커밋에 남을 내 정보를 설정해요.\n  git config user.name \"%s\"\n  git config user.email \"newhire@nexora.dev\"",
				"Set who your commits come from.\n  git config user.name \"%s\"\n  git config user.email \"newhire@nexora.dev\"")},
		{"id": "history", "app": "terminal",
			"text": t("git status 와 git log --oneline 으로 상태와 기록 보기", "Check git status and git log --oneline"),
			"guide": t("git status 는 지금 상태를, git log --oneline 은 지금까지의 커밋 기록을 한 줄씩 보여줘요. 둘 다 입력해 보세요.",
				"git status shows the current state; git log --oneline shows the commit history, one per line. Try both.")},
	]
	hints = [
		t("독(화면 아래 아이콘 줄)에서 앱을 열 수 있어요. 지금 해야 할 일은 왼쪽 아래 가이드 카드에 나와요.", "Open apps from the dock at the bottom. Your current step is in the guide card at the bottom left."),
		t("터미널 명령은 정확히 입력해야 해요. 예: git config user.email \"newhire@nexora.dev\"", "Terminal commands must be typed exactly, e.g. git config user.email \"newhire@nexora.dev\""),
	]


func begin() -> void:
	# the player's name in the identity step
	for o in objectives:
		if o["id"] == "identity":
			o["guide"] = t(o["guide"]["ko"] % Game.pname(), o["guide"]["en"] % Game.pname())
	Game.add_issue("#002", Game.LL("로그인 타임아웃 처리 (1차)", "Login timeout handling (part 1)"), "bug", "Daniel", "done")
	Game.add_issue("#003", Game.LL("주문 목록 페이지네이션", "Order list pagination"), "feature", "Sophie", "progress")
	await wait(1.2)
	if not is_current():
		return
	say("system", t("오늘부터 NEXORA 개발팀에 합류한 %s 님을 환영합니다!" % Game.pname(), "Please welcome %s, who joins the NEXORA dev team today!" % Game.pname()),
		{"channel": "general", "silent": true})
	choice("alex", t("%s 님, 환영해요. 커머스팀 PM Alex예요. NEXORA는 작은 온라인 상점이 주문을 받고 결제를 관리할 수 있는 Commerce Cloud를 만들어요. 우리 팀은 그 주문과 결제가 오가는 서버를 맡아요. 오늘은 팀을 둘러보고 첫 변경을 리뷰에 올려 볼 거예요. Sophie가 온보딩을 도와줄 거예요." % Game.pname(),
		"Welcome, %s. I'm Alex, the commerce team's PM. NEXORA makes Commerce Cloud, which helps small online shops take orders and manage payments. We look after the servers that handle those orders and payments. Today you'll meet the team and send your first change for review. Sophie will help you get set up." % Game.pname()),
		"d1_hello", [["warm", t("안녕하세요! 잘 부탁드립니다 :)", "Hi! Great to be here :)")], ["ready", t("네, 바로 시작하겠습니다.", "Thanks, I'll get started right away.")]],
		{"link": {"app": "browser", "target": "portal/start", "label": t("첫 출근 안내 열기", "Open the first-day guide")}})


func resume() -> void:
	for o in objectives:
		if o["id"] == "identity":
			o["guide"] = t(o["guide"]["ko"].replace("%s", Game.pname()), o["guide"]["en"].replace("%s", Game.pname()))
	super.resume()


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"choice":
			if d["key"] == "d1_hello":
				Game.relate("alex", {"close": 3} if d["option"] == "warm" else {"work": 2})
				complete("hello")
				await wait(1.0)
				if not is_current():
					return
				say("sophie", t("온보딩 버디 Sophie예요. 저는 점주가 보는 주문 목록을 만들고 있어요. 점주에게 같은 주문이 두 줄로 뜨면 포장할 물건도 두 개로 보이거든요. Wiki의 '온보딩 가이드'에 우리가 이런 변경을 어떻게 검토하는지 정리해 뒀어요.",
					"I'm Sophie, your onboarding buddy. I'm working on the order list that shop owners see. If an order shows up twice, it looks like they need to pack twice as much. The Wiki's Onboarding guide explains how we review changes like this."))
		"wiki_page":
			if d["page"] == "workflow" and is_done("hello"):
				complete("wiki")
				await wait(1.0)
				if not is_current():
					return
				say("sophie", t("다 읽었어요? 이제 터미널을 열어 볼게요. help 를 치면 쓸 수 있는 명령이 나와요.",
					"Done? Now let's open the Terminal. Type help to see what you can do."))
		"cmd":
			var argv: Array = d["argv"]
			if argv.is_empty():
				return
			if argv[0] == "help":
				complete("help")
			if argv[0] == "ls":
				data()["ls"] = true
			if argv[0] == "cat" and argv.size() > 1 and String(argv[1]).to_lower().contains("readme"):
				data()["cat"] = true
			if data().get("ls", false) and data().get("cat", false) and not is_done("explore"):
				complete("explore")
				say("sophie", t("README에 우리 서비스 소개가 있죠? 이제 커밋에 남을 내 이름과 이메일을 설정해야 해요. 가이드 카드를 보세요!",
					"See the service intro in the README? Next, set the name and email your commits will carry. Check the guide card!"))
		"command_finished":
			if int(d.get("code", -1)) != 0:
				return
			var argv: Array = d["argv"]
			if is_git(argv, "config"):
				var name := String(await Workspace.git_config("user.name"))
				if not is_current():
					return
				var email := String(await Workspace.git_config("user.email"))
				if not is_current():
					return
				if name != "" and "@" in email and not is_done("identity"):
					complete("identity")
					say("sophie", t("좋아요, 이제 커밋에 '%s'로 남아요. 마지막으로 git status 와 git log --oneline 을 쳐 보세요." % name,
						"Nice, your commits will now say '%s'. Finally, try git status and git log --oneline." % name))
			if is_git(argv, "status"):
				data()["status"] = true
			if is_git(argv, "log"):
				data()["log"] = true
			if data().get("status", false) and data().get("log", false) and is_done("identity"):
				complete("history")
	if all_done() and not data().get("finished", false):
		data()["finished"] = true
		Game.relate("sophie", {"close": 3})
		await wait(1.0)
		if not is_current():
			return
		say("sophie", t("완벽해요! 이제 진짜 업무를 해 볼 차례예요. Daniel이 첫 업무를 줄 거예요.",
			"Perfect! Time for real work. Daniel will give you your first task."))
		finish()
