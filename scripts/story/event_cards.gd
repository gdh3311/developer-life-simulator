extends RefCounted
## Event card data. Fields (see scripts/story/events.gd):
##   cat: daily | office | crisis | life | industry      format: chat | call | desk_visit | popup
##   from: NPC id · channel (chat) · title/text {ko,en} · window [from, to] minutes · weight
##   chapters [min, max] · days [fixed days] (curated) · once · cooldown (days) · chain_only
##   cond: rank_min, condition_max, owned, not_owned, flag, not_flag, arc_active
##   decline: choice used when a call is declined
##   choices: [{ id, label, rel {npc: {key: delta}}, cond, money, mins, flag [k, v], own, reply [npc, text],
##              chain [card, days_later, minutes] }]


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


static var ALL := {
	# --- daily -------------------------------------------------------------------------
	"lunch_vote": {
		"cat": "daily", "format": "chat", "from": "mina", "channel": "general", "window": [11 * 60 + 20, 11 * 60 + 50],
		"weight": 2.0, "once": false, "cooldown": 2,
		"text": t("점심 투표! 국밥 vs 샐러드 vs 편의점. 5분 안에 안 정하면 국밥이에요.", "Lunch vote! Soup vs salad vs convenience store. No answer in 5 minutes means soup."),
		"choices": [
			{"id": "join", "label": t("국밥 콜. 같이 가요!", "Soup it is. I'm in!"), "rel": {"mina": {"close": 2}, "sophie": {"close": 1}}, "cond": 8, "mins": 10},
			{"id": "desk", "label": t("오늘은 자리에서 먹을게요.", "I'll eat at my desk today."), "cond": -2},
		],
	},
	"coffee_broken": {
		"cat": "daily", "format": "desk_visit", "from": "mina", "window": [9 * 60 + 30, 11 * 60],
		"cond": {"not_owned": "coffee_machine"},
		"text": t("탕비실 커피 머신이 또 멈췄어요... 혹시 이런 거 잘 고쳐요? 에러 코드가 E-17이래요.", "The kitchen coffee machine stopped again... are you good with these? It says error E-17."),
		"choices": [
			{"id": "fix", "label": t("같이 가 봐요. 물통부터 확인해 보죠.", "Let's take a look. Check the water tank first."), "rel": {"mina": {"close": 3}}, "cond": 6, "mins": 10,
				"reply": ["mina", t("물통이었네요ㅋㅋ 오늘의 영웅이에요.", "It was the tank lol. Hero of the day.")]},
			{"id": "pass", "label": t("지금은 손을 못 떼요. 시설팀에 말해 볼게요.", "Can't step away right now. I'll ping facilities.")},
		],
	},
	"keyboard_noise": {
		"cat": "daily", "format": "chat", "from": "sophie", "window": [10 * 60, 15 * 60], "cond": {"owned": "keyboard_rgb"},
		"text": t("저기... 새 키보드 소리가 좀 커서요ㅠ 회의 때 마이크에 들어가요.", "Um... your new keyboard is a bit loud ㅠ It gets picked up by the mic in meetings."),
		"choices": [
			{"id": "keycaps", "label": t("저소음 스위치로 바꿀게요. 말해 줘서 고마워요.", "I'll switch to silent switches. Thanks for telling me."), "money": -15000, "rel": {"sophie": {"close": 2, "agree": 1}}},
			{"id": "ignore", "label": t("이게 타건감이 좋아서요...", "But the typing feel is so good..."), "rel": {"sophie": {"close": -2}}},
		],
	},
	"emoji_war": {
		"cat": "daily", "format": "chat", "from": "sophie", "channel": "general", "window": [13 * 60 + 30, 16 * 60],
		"text": t("#general에서 '배포 완료' 이모지 투표 중이에요. 🚀 vs 🫡 vs 🍞(?)", "#general is voting on the 'deployed' emoji. 🚀 vs 🫡 vs 🍞(?)"),
		"choices": [
			{"id": "bread", "label": t("🍞. 갓 구운 배포.", "🍞. Freshly baked deploys."), "rel": {"sophie": {"close": 2}, "mina": {"close": 1}}},
			{"id": "skip", "label": t("(조용히 🚀 누르고 일로 돌아간다)", "(quietly vote 🚀 and get back to work)")},
		],
	},
	# --- office ------------------------------------------------------------------------
	"security_training": {
		"cat": "office", "format": "popup", "from": "system", "window": [9 * 60 + 40, 11 * 60], "once": false, "cooldown": 7,
		"title": t("보안 교육 미이수", "Security training overdue"),
		"text": t("분기 보안 교육(30분)을 아직 듣지 않았습니다. 이번 주 안에 이수해 주세요.", "You haven't completed this quarter's security training (30 min). Please finish it this week."),
		"choices": [
			{"id": "now", "label": t("지금 듣기 (30분)", "Take it now (30 min)"), "mins": 30, "flag": ["security_training", true], "cond": -3},
			{"id": "later", "label": t("나중에", "Later"), "chain": ["security_reminder", 1, 10 * 60]},
		],
	},
	"security_reminder": {
		"cat": "office", "format": "popup", "from": "system", "chain_only": true, "once": false,
		"title": t("보안 교육 미이수 · 2일째", "Security training overdue · day 2"),
		"text": t("내일까지 이수하지 않으면 팀장에게 알림이 갑니다.", "If it isn't done by tomorrow, your lead will be notified."),
		"choices": [
			{"id": "now", "label": t("지금 듣기 (30분)", "Take it now (30 min)"), "mins": 30, "flag": ["security_training", true]},
			{"id": "later", "label": t("또 미루기", "Put it off again"), "rel": {"alex": {"work": -2}}},
		],
	},
	"townhall": {
		"cat": "office", "format": "popup", "from": "system", "days": [8], "window": [10 * 60 + 5, 10 * 60 + 5],
		"title": t("전사 타운홀", "Company town hall"),
		"text": t("CEO: \"이번 분기 신규 계약이 두 배가 됐습니다. 예약 판매가 그 데모의 중심이에요.\" 질문 시간입니다.", "CEO: \"New contracts doubled this quarter. Pre-orders are the centerpiece of the demo.\" Q&A time."),
		"choices": [
			{"id": "ask", "label": t("손 들고 묻기: 계약이 늘면 지원 인력도 늘어나나요?", "Raise a hand: will support staff grow with the contracts?"), "rel": {"alex": {"agree": 2}, "mina": {"close": 1}}, "mins": 20,
				"reply": ["alex", t("타운홀 질문 좋았어요. 다들 궁금했는데 아무도 안 물어봤거든요.", "Great town hall question. Everyone wondered and nobody asked.")]},
			{"id": "listen", "label": t("조용히 듣기", "Just listen"), "mins": 20},
		],
	},
	"sophie_visit": {
		"cat": "office", "format": "desk_visit", "from": "sophie", "window": [14 * 60, 16 * 60 + 30], "once": false, "cooldown": 3,
		"text": t("잠깐 시간 돼요? 테스트가 제 컴퓨터에서만 통과해요... 5분이면 될 것 같은데.", "Got a minute? My tests only pass on my machine... probably five minutes."),
		"choices": [
			{"id": "help", "label": t("같이 봐요. 시간대 설정 먼저 확인해 보죠.", "Let's look. Check the time-zone setting first."), "rel": {"sophie": {"tech": 2, "close": 2}}, "mins": 15,
				"reply": ["sophie", t("진짜 시간대였어요...! 고마워요!!", "It really was the time zone...! Thank you!!")]},
			{"id": "later", "label": t("4시에 같이 봐요. 그 전에 뭘 해 봤는지 적어 와요.", "Let's look at 4. Write down what you tried before then."), "rel": {"sophie": {"agree": 1}}},
			{"id": "busy", "label": t("지금은 어려워요.", "Not right now."), "rel": {"sophie": {"close": -2}}},
		],
	},
	# --- crisis (on-call chain) ---------------------------------------------------------
	"oncall_page": {
		"cat": "crisis", "format": "call", "from": "daniel", "window": [9 * 60 + 20, 10 * 60 + 30], "weight": 0.8,
		"cond": {"rank_min": 1}, "decline": "miss",
		"text": t("결제 대행사 응답이 갑자기 느려졌어요. 주문 실패가 조금씩 올라가요. 지금 같이 볼 수 있어요?", "The payment provider suddenly got slow and order failures are creeping up. Can you look with me now?"),
		"choices": [
			{"id": "rollback", "label": t("어제 배포부터 되돌리고 원인을 봐요.", "Roll back yesterday's deploy first, then investigate."), "rel": {"daniel": {"tech": 3, "agree": 2}}, "mins": 20,
				"chain": ["oncall_retro", 1, 9 * 60 + 40]},
			{"id": "solo", "label": t("제가 혼자 볼게요. 다른 분들은 하던 거 하세요.", "I'll handle it alone. Everyone else carry on."), "mins": 45, "cond": -8, "rel": {"daniel": {"tech": 1}},
				"chain": ["oncall_retro", 1, 9 * 60 + 40]},
			{"id": "miss", "label": t("(전화를 받지 못했다)", "(missed the call)"), "rel": {"daniel": {"work": -3}}, "chain": ["oncall_retro", 1, 9 * 60 + 40]},
		],
	},
	"oncall_retro": {
		"cat": "crisis", "format": "chat", "from": "daniel", "chain_only": true,
		"text": t("어제 호출 건, 짧게 회고 남길까요? 무슨 일이 있었는지, 다음엔 뭘 다르게 할지만요.", "About yesterday's page: shall we write a short retro? Just what happened and what we'd do differently."),
		"choices": [
			{"id": "honest", "label": t("제가 놓친 것까지 그대로 적을게요.", "I'll write it as it was, including what I missed."), "rel": {"daniel": {"agree": 3}}, "flag": ["incident_notes", true],
				"chain": ["oncall_coffee", 0, 15 * 60]},
			{"id": "brief", "label": t("별일 아니었으니 한 줄만 쓸게요.", "It was minor; one line is enough."), "rel": {"daniel": {"agree": -2}}},
		],
	},
	"oncall_coffee": {
		"cat": "crisis", "format": "desk_visit", "from": "alex", "chain_only": true,
		"text": t("회고 읽었어요. 숨기지 않고 써 줘서 고마워요. 커피 사 왔어요.", "I read the retro. Thanks for not hiding anything. I brought coffee."),
		"choices": [
			{"id": "thanks", "label": t("감사합니다. 덕분에 살았네요.", "Thank you. I needed that."), "cond": 8, "rel": {"alex": {"close": 3}}},
			{"id": "focus", "label": t("고마워요. 마저 하고 마실게요.", "Thanks. I'll drink it after I finish this."), "rel": {"alex": {"close": 1}}},
		],
	},
	# --- life --------------------------------------------------------------------------
	"family_call": {
		"cat": "life", "format": "call", "from": "family", "window": [16 * 60 + 30, 17 * 60 + 30], "weight": 1.2, "decline": "later",
		"text": t("밥은 먹고 다니니? 요즘 회사는 어때. 주말에 올 수 있어?", "Are you eating properly? How's work these days? Can you come by this weekend?"),
		"choices": [
			{"id": "talk", "label": t("응, 잘 지내. 주말에 갈게.", "I'm good. I'll come this weekend."), "cond": 8, "mins": 10},
			{"id": "later", "label": t("지금 회사라서, 이따 전화할게!", "I'm at work, I'll call you back!"), "cond": -2},
		],
	},
	"rent_notice": {
		"cat": "life", "format": "popup", "from": "system", "chapters": [3, 99], "window": [12 * 60, 13 * 60],
		"title": t("임대차 갱신 안내", "Lease renewal notice"),
		"text": t("다음 달부터 월세가 5만원 오릅니다. 회신 부탁드립니다. — 집주인", "Rent goes up by 50,000 KRW from next month. Please reply. — Landlord"),
		"choices": [
			{"id": "accept", "label": t("그대로 받아들인다", "Accept it"), "money": -50000},
			{"id": "negotiate", "label": t("2년 계약을 조건으로 협상한다", "Negotiate in exchange for a two-year lease"), "money": -20000, "cond": -3, "flag": ["rent_negotiated", true]},
			{"id": "move", "label": t("회사 근처로 이사를 알아본다", "Start looking for a place near the office"), "flag": ["move_plan", true]},
		],
	},
	"cold": {
		"cat": "life", "format": "popup", "from": "system", "window": [9 * 60 + 10, 15 * 60], "once": false, "cooldown": 3,
		"cond": {"condition_max": 30},
		"title": t("몸이 무겁다", "Feeling run down"),
		"text": t("목이 칼칼하고 머리가 무겁다. 요 며칠 너무 달렸다.", "Scratchy throat, heavy head. You've been pushing too hard these past few days."),
		"choices": [
			{"id": "rest", "label": t("오늘은 무리하지 않는다 (속도를 늦춘다)", "Take it easy today"), "cond": 15, "rel": {"alex": {"close": 1}}},
			{"id": "push", "label": t("약 먹고 버틴다", "Take a pill and push through"), "cond": -5},
		],
	},
	# --- industry ------------------------------------------------------------------------
	"competitor_news": {
		"cat": "industry", "format": "popup", "from": "system", "window": [10 * 60, 15 * 60],
		"title": t("DevDaily 속보", "DevDaily breaking"),
		"text": t("경쟁사 커머스 플랫폼, 재시도 폭주로 주문 중복 장애… 판매자 수천 곳 영향", "Rival commerce platform hit by retry storm, duplicate orders… thousands of sellers affected"),
		"choices": [
			{"id": "propose", "label": t("우리 시스템도 같은 상황을 점검하자고 제안한다", "Propose checking our system for the same scenario"), "rel": {"daniel": {"tech": 2}}, "flag": ["competitor_check", true],
				"reply": ["daniel", t("좋은 제안이에요. 우리 재시도 계약 테스트를 그 시나리오로 한 번 더 돌려 봐요.", "Good call. Let's run our retry contract tests against that scenario once more.")]},
			{"id": "read", "label": t("읽고 넘어간다", "Read it and move on")},
		],
	},
	# --- volume batch 1: choices that come back the next day --------------------------------
	"sophie_review": {
		"cat": "office", "format": "chat", "from": "sophie", "window": [10 * 60 + 30, 15 * 60], "chapters": [2, 99],
		"text": t("제 PR에 리뷰 좀 해 줄 수 있어요? 첫 백엔드 PR이라 떨려요. 급한 건 아니에요.", "Could you review my PR? It's my first backend one and I'm nervous. No rush."),
		"choices": [
			{"id": "careful", "label": t("천천히 읽고 질문 위주로 코멘트한다", "Read it properly and comment with questions"), "mins": 25, "rel": {"sophie": {"tech": 2, "close": 2}},
				"chain": ["sophie_pair", 1, 14 * 60]},
			{"id": "quick", "label": t("훑어보고 바로 승인한다", "Skim it and approve"), "mins": 5, "chain": ["sophie_hotfix", 1, 10 * 60]},
		],
	},
	"sophie_pair": {
		"cat": "office", "format": "desk_visit", "from": "sophie", "chain_only": true,
		"text": t("어제 질문들 덕분에 엣지 케이스 두 개를 찾았어요. 오늘 30분만 페어로 같이 봐 줄래요?", "Your questions yesterday found two edge cases. Could we pair for 30 minutes today?"),
		"choices": [
			{"id": "pair", "label": t("좋아요, 같이 봐요", "Sure, let's pair"), "mins": 30, "rel": {"sophie": {"tech": 2, "close": 3}}, "flag": ["sophie_paired", true]},
			{"id": "later", "label": t("오늘은 어렵고 메모로 남겨 줄게요", "Not today; I'll leave notes"), "rel": {"sophie": {"close": 1}}},
		],
	},
	"sophie_hotfix": {
		"cat": "office", "format": "chat", "from": "sophie", "chain_only": true,
		"text": t("어제 그 PR... 빈 장바구니에서 에러가 났대요ㅠ 핫픽스 올렸어요. 다음엔 제가 테스트를 더 적을게요.", "That PR yesterday... it errored on empty carts ㅠ I pushed a hotfix. I'll write more tests next time."),
		"choices": [
			{"id": "own", "label": t("승인한 저도 놓쳤어요. 같이 테스트 추가해요", "I approved it, so I missed it too. Let's add the test together"), "mins": 15, "rel": {"sophie": {"close": 3}, "daniel": {"agree": 1}}},
			{"id": "shrug", "label": t("그럴 수 있죠", "It happens")},
		],
	},
	"friday_deploy": {
		"cat": "office", "format": "chat", "from": "alex", "window": [16 * 60 + 30, 17 * 60 + 20], "chapters": [2, 99],
		"text": t("문구 하나만 바꾸는 배포인데 지금 내보내도 될까요? 고객이 내일 아침 전에 보고 싶대요.", "It's a one-line copy change. Can we ship it now? The customer wants to see it before tomorrow morning."),
		"choices": [
			{"id": "now", "label": t("작으니까 지금 배포해요", "It's small, ship it now"), "mins": 15, "rel": {"alex": {"agree": 2}}, "chain": ["weekend_ping", 1, 9 * 60 + 30]},
			{"id": "morning", "label": t("내일 아침 다 같이 보고 있을 때 내보내요", "Ship tomorrow morning while we're all watching"), "rel": {"alex": {"agree": -1}, "daniel": {"work": 2}},
				"chain": ["monday_calm", 1, 10 * 60]},
		],
	},
	"weekend_ping": {
		"cat": "crisis", "format": "chat", "from": "daniel", "chain_only": true,
		"text": t("어제 배포한 문구, 영어 화면에서 줄바꿈이 깨져서 버튼이 안 보였대요. 밤에 제가 되돌려 놨어요.", "Yesterday's copy change broke line wrapping on the English screen and hid a button. I rolled it back last night."),
		"choices": [
			{"id": "retro", "label": t("고마워요. 영어 화면 확인을 배포 체크리스트에 넣을게요", "Thanks. I'll add an English-screen check to the deploy checklist"), "rel": {"daniel": {"work": 2}}, "flag": ["deploy_checklist", true]},
			{"id": "sorry", "label": t("죄송해요, 다음엔 조심할게요", "Sorry, I'll be careful next time"), "rel": {"daniel": {"work": -1}}},
		],
	},
	"monday_calm": {
		"cat": "office", "format": "chat", "from": "alex", "chain_only": true,
		"text": t("아침 배포 잘 나갔어요. 고객도 확인하고 좋대요. 어제는 제가 좀 조급했네요.", "This morning's deploy went fine and the customer liked it. I was a bit impatient yesterday."),
		"choices": [{"id": "ok", "label": t("다음에도 같이 봐요", "Let's keep doing it this way"), "rel": {"alex": {"agree": 2}}}],
	},
	"flaky_test": {
		"cat": "crisis", "format": "chat", "from": "mina", "window": [10 * 60, 15 * 60], "chapters": [2, 99],
		"text": t("main에서 테스트 하나가 가끔 실패해요. 다시 돌리면 통과하고요. 시간 의존 테스트 같아요.", "One test on main fails now and then and passes on rerun. Looks time-dependent."),
		"choices": [
			{"id": "dig", "label": t("가상 시계로 고정해 볼게요", "I'll pin it with a fake clock"), "mins": 30, "rel": {"mina": {"tech": 3}}, "flag": ["flaky_fixed", true]},
			{"id": "rerun", "label": t("일단 다시 돌려 두죠", "Just rerun it for now"), "chain": ["flaky_again", 1, 11 * 60]},
		],
	},
	"flaky_again": {
		"cat": "crisis", "format": "chat", "from": "mina", "chain_only": true,
		"text": t("그 테스트가 오늘은 Sophie PR에서 터져서, Sophie가 한 시간 동안 자기 코드를 의심했어요.", "That test blew up in Sophie's PR today, and she spent an hour doubting her own code."),
		"choices": [
			{"id": "fix", "label": t("지금 고칠게요. 가상 시계로요", "I'll fix it now, with a fake clock"), "mins": 30, "rel": {"mina": {"tech": 2}, "sophie": {"close": 2}}, "flag": ["flaky_fixed", true]},
			{"id": "skip", "label": t("건너뛰기 표시를 해 둘게요", "I'll mark it as skipped"), "rel": {"mina": {"agree": -2}}},
		],
	},
	"phishing_mail": {
		"cat": "office", "format": "popup", "from": "system", "window": [9 * 60 + 20, 16 * 60], "chapters": [2, 99],
		"title": t("메일: [CodeHub] 비밀번호를 재설정하세요", "Mail: [CodeHub] Reset your password"),
		"text": t("보낸 사람 codehub-security@c0dehub-mail.net · '24시간 안에 재설정하지 않으면 저장소 접근이 막힙니다.'", "From codehub-security@c0dehub-mail.net · 'Reset within 24 hours or lose repository access.'"),
		"choices": [
			{"id": "report", "label": t("Taeseok에게 피싱으로 신고한다", "Report it to Taeseok as phishing"), "flag": ["phish_reported", true],
				"reply": ["taeseok", t("신고 고마워요. 도메인에 숫자 0이 들어 있죠? 오늘 세 명이 같은 메일을 받았어요. 전사 공지 낼게요.", "Thanks for reporting. See the zero in the domain? Three people got it today. I'll send a company notice.")]},
			{"id": "open", "label": t("링크를 열어 본다", "Open the link"), "chain": ["phish_followup", 1, 9 * 60 + 15]},
		],
	},
	"phish_followup": {
		"cat": "office", "format": "chat", "from": "taeseok", "chain_only": true,
		"text": t("어제 그 피싱 링크를 연 기록이 있어요. 비밀번호는 안 넣으셨죠? 혹시 몰라 세션을 끊고 토큰을 다시 발급했어요.", "Our logs show you opened yesterday's phishing link. You didn't enter a password, right? Just in case, I cut your sessions and reissued your token."),
		"choices": [
			{"id": "thanks", "label": t("안 넣었어요. 고마워요, 주소를 더 꼼꼼히 볼게요", "I didn't. Thanks, I'll read addresses more carefully"), "flag": ["phish_lesson", true]},
		],
	},
	"meetup_talk": {
		"cat": "industry", "format": "chat", "from": "daniel", "window": [12 * 60 + 30, 16 * 60], "chapters": [3, 99],
		"text": t("판교 백엔드 밋업에서 10분 발표자를 찾는대요. 중복 주문 이야기 해 보는 거 어때요? 회사 정보만 빼면 돼요.", "The Pangyo backend meetup needs a 10-minute speaker. How about the duplicate-order story? Just leave out company details."),
		"choices": [
			{"id": "yes", "label": t("해 볼게요", "I'll do it"), "rel": {"daniel": {"close": 2}}, "flag": ["meetup_talk", true], "chain": ["meetup_night", 2, 17 * 60 + 30]},
			{"id": "no", "label": t("이번엔 듣기만 할게요", "I'll just listen this time")},
		],
	},
	"meetup_night": {
		"cat": "industry", "format": "popup", "from": "system", "chain_only": true,
		"title": t("밋업 발표 날", "Meetup talk night"),
		"text": t("떨렸지만 끝났다. 질문이 다섯 개나 나왔고, 한 명은 '우리도 똑같이 겪었다'며 명함을 줬다.", "You were nervous, but it's done. Five questions, and someone handed you a card saying 'we went through exactly that.'"),
		"choices": [
			{"id": "share", "label": t("발표 자료를 팀 Wiki에 올린다", "Post the slides on the team Wiki"), "rel": {"alex": {"close": 1}, "daniel": {"agree": 2}}, "cond": -4},
			{"id": "rest", "label": t("집에 가서 바로 잔다", "Go home and sleep"), "cond": 4},
		],
	},
	"os_update": {
		"cat": "daily", "format": "popup", "from": "system", "window": [9 * 60 + 15, 11 * 60 + 30], "once": false, "cooldown": 6,
		"title": t("업데이트 준비 완료", "Updates ready"),
		"text": t("보안 업데이트를 설치하려면 다시 시작해야 합니다. (약 20분)", "A restart is needed to install security updates. (about 20 minutes)"),
		"choices": [
			{"id": "now", "label": t("지금 설치 (커피 타러 간다)", "Install now (go make coffee)"), "mins": 20, "cond": 3},
			{"id": "later", "label": t("내일 다시 알림", "Remind me tomorrow"), "chain": ["os_forced", 1, 9 * 60 + 5]},
		],
	},
	"os_forced": {
		"cat": "daily", "format": "popup", "from": "system", "chain_only": true, "once": false,
		"title": t("업데이트를 미룰 수 없습니다", "Updates can't wait any longer"),
		"text": t("보안 정책에 따라 지금 다시 시작합니다. 열려 있던 터미널 세션이 닫혔다.", "Restarting now per security policy. Your open terminal sessions were closed."),
		"choices": [{"id": "ok", "label": t("…네", "…okay"), "mins": 30, "cond": -3}],
	},
}
