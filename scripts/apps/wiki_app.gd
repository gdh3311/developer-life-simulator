extends HSplitContainer
## Company Wiki: specs, rules and cheat sheets (the source of truth for missions).

const UITheme := preload("res://scripts/ui/ui_theme.gd")

const PAGES := [
	["overview", {"ko": "Commerce Cloud 개요", "en": "Commerce Cloud overview"}],
	["workflow", {"ko": "온보딩 가이드", "en": "Onboarding guide"}],
	["rules", {"ko": "협업 규칙", "en": "Team rules"}],
	["names", {"ko": "사용자 이름 표시 규칙", "en": "Display name rules"}],
	["coupon", {"ko": "쿠폰 정책", "en": "Coupon policy"}],
	["shipping", {"ko": "배송비 정책", "en": "Shipping policy"}],
	["auth", {"ko": "인증 / 장애 대응", "en": "Auth & incidents"}],
	["git", {"ko": "Git 치트시트", "en": "Git cheat sheet"}],
]

var _page := "overview"
var _nav: VBoxContainer
var _text: RichTextLabel


func _ready() -> void:
	split_offset = 210
	var left := UITheme.panel(UITheme.BG0, 0, 8, Color(0, 0, 0, 0))
	left.custom_minimum_size.x = 200
	_nav = UITheme.vbox(2)
	left.add_child(_nav)
	add_child(left)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.selection_enabled = true
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG1, 0, Color(0, 0, 0, 0), 22))
	_text.add_theme_font_override("normal_font", UITheme.font())
	_text.add_theme_font_override("bold_font", UITheme.font(false, true))
	_text.add_theme_font_override("mono_font", UITheme.font(true))
	_text.add_theme_font_size_override("normal_font_size", 14)
	_text.add_theme_font_size_override("bold_font_size", 14)
	_text.add_theme_font_size_override("mono_font_size", 13)
	_text.add_theme_constant_override("line_separation", 4)
	add_child(_text)
	if Story.active != null and Story.active.id == "d1_01":
		_page = "workflow" if Story.active.is_done("hello") else "overview"
	_render()


func _render() -> void:
	UITheme.clear(_nav)
	_nav.add_child(UITheme.label("  NEXORA Wiki", 11, UITheme.MUTED))
	for p in PAGES:
		var id: String = p[0]
		var b := Button.new()
		b.text = Game.tx(p[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UITheme.box(Color("22c3c3").darkened(0.7) if id == _page else Color(0, 0, 0, 0), 6, Color(0, 0, 0, 0), 6))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.05), 6, Color(0, 0, 0, 0), 6))
		b.add_theme_color_override("font_color", UITheme.TEXT if id == _page else UITheme.TEXT2)
		b.pressed.connect(func() -> void:
			_page = id
			_render())
		_nav.add_child(b)
	_text.text = _content(_page)
	_text.scroll_to_line(0)
	Game.emit_event("wiki_page", {"page": _page})


static func _h(t: String) -> String:
	return "[font_size=24][b]%s[/b][/font_size]\n" % t


static func _s(t: String) -> String:
	return "\n[color=#22c3c3][b]%s[/b][/color]\n" % t


static func _c(t: String) -> String:
	return "[bgcolor=#1e2433][code] %s [/code][/bgcolor]" % t


func _content(id: String) -> String:
	var en := Game.lang == "en"
	match id:
		"overview":
			if en:
				return _h("Commerce Cloud") + "[color=#8a93a5]NEXORA's B2B commerce SaaS backend · repository %s[/color]\n" % _c("commerce-api") \
					+ _s("Layout") \
					+ "  • %s — login, sessions\n  • %s — orders, coupons, shipping\n  • %s — payments\n  • %s — user profiles\n  • %s — tests (Node test runner)\n" % [_c("src/auth"), _c("src/orders"), _c("src/payments"), _c("src/users"), _c("tests/")] \
					+ _s("Team") \
					+ "  • [b]Alex Kim[/b] — PM. Schedule and priorities\n  • [b]Daniel Park[/b] — Senior backend. Reviews and merges\n  • [b]Mina Choi[/b] — QA. Reproduces and verifies bugs\n  • [b]Sophie Lee[/b] — Junior frontend. Your onboarding buddy\n" \
					+ _s("Environment") \
					+ "  • Remote: %s\n  • Your working copy: %s\n  • Hosting / PRs / CI: the [b]CodeHub[/b] app\n" % [_c("nexora.dev:commerce/commerce-api.git"), _c("~/commerce-api")]
			return _h("Commerce Cloud") + "[color=#8a93a5]NEXORA의 B2B 커머스 SaaS 백엔드 · 저장소 %s[/color]\n" % _c("commerce-api") \
				+ _s("구조") \
				+ "  • %s — 로그인, 세션\n  • %s — 주문, 쿠폰, 배송비\n  • %s — 결제\n  • %s — 사용자 프로필\n  • %s — 테스트 (Node 테스트 러너)\n" % [_c("src/auth"), _c("src/orders"), _c("src/payments"), _c("src/users"), _c("tests/")] \
				+ _s("팀") \
				+ "  • [b]Alex Kim[/b] — PM. 일정과 우선순위\n  • [b]Daniel Park[/b] — 시니어 백엔드. 리뷰와 병합 담당\n  • [b]Mina Choi[/b] — QA. 버그 재현과 검증\n  • [b]Sophie Lee[/b] — 주니어 프론트엔드. 온보딩 버디\n" \
				+ _s("환경") \
				+ "  • 원격 저장소: %s\n  • 내 작업 사본: %s\n  • 코드 호스팅 / PR / CI: [b]CodeHub[/b] 앱\n" % [_c("nexora.dev:commerce/commerce-api.git"), _c("~/commerce-api")]
		"workflow":
			if en:
				return _h("Onboarding guide") \
					+ _s("1. Terminal basics") \
					+ "  • %s — list commands   %s — list files   %s — print a file\n" % [_c("help"), _c("ls"), _c("cat README.md")] \
					+ "  • Use ↑/↓ to recall earlier commands.\n" \
					+ _s("2. Tell git who you are (once)") \
					+ "  %s\n  %s\n" % [_c("git config user.name \"Your Name\""), _c("git config user.email \"you@nexora.dev\"")] \
					+ _s("3. How a change ships") \
					+ "  1. Get the latest code: %s → %s\n" % [_c("git switch main"), _c("git pull")] \
					+ "  2. Create a branch: %s\n" % _c("git switch -c fix/what-you-fix") \
					+ "  3. Edit in DevIDE, save with %s, check with %s and %s\n" % [_c("Ctrl+S"), _c("git diff"), _c("npm test")] \
					+ "  4. Commit: %s → %s\n" % [_c("git add ."), _c("git commit -m \"fix: what and why\"")] \
					+ "  5. Upload: %s\n" % _c("git push") \
					+ "  6. Open a PR in [b]CodeHub[/b] with a description → CI runs → a senior reviews\n" \
					+ "  7. The senior approves and [b]merges[/b]. Then update main: %s, %s\n" % [_c("git switch main"), _c("git pull")] \
					+ _s("Permissions") \
					+ "  • Interns and juniors [b]open PRs[/b] and [b]leave review comments[/b].\n  • Only seniors (Daniel) [b]approve and merge[/b].\n" \
					+ _s("Tips") + "  • Prefix commit messages: %s %s %s %s\n  • Stuck? AICode has [b]hints[/b].\n" % [_c("fix:"), _c("feat:"), _c("docs:"), _c("test:")]
			return _h("온보딩 가이드") \
				+ _s("1. 터미널 기초") \
				+ "  • %s — 명령 목록   %s — 파일 목록   %s — 파일 내용 보기\n" % [_c("help"), _c("ls"), _c("cat README.md")] \
				+ "  • ↑/↓ 키로 이전 명령을 불러올 수 있어요.\n" \
				+ _s("2. git에 내 정보 알려주기 (처음 한 번)") \
				+ "  %s\n  %s\n" % [_c("git config user.name \"내 이름\""), _c("git config user.email \"me@nexora.dev\"")] \
				+ _s("3. 변경이 반영되는 흐름") \
				+ "  1. 최신 코드 받기: %s → %s\n" % [_c("git switch main"), _c("git pull")] \
				+ "  2. 작업 브랜치 만들기: %s\n" % _c("git switch -c fix/고칠-내용") \
				+ "  3. DevIDE에서 수정, %s 저장, %s 와 %s 로 확인\n" % [_c("Ctrl+S"), _c("git diff"), _c("npm test")] \
				+ "  4. 커밋: %s → %s\n" % [_c("git add ."), _c("git commit -m \"fix: 무엇을 왜\"")] \
				+ "  5. 올리기: %s\n" % _c("git push") \
				+ "  6. [b]CodeHub[/b]에서 설명을 적어 PR 만들기 → CI 실행 → 시니어 리뷰\n" \
				+ "  7. 시니어가 승인하고 [b]병합[/b]. 그 다음 main 최신화: %s, %s\n" % [_c("git switch main"), _c("git pull")] \
				+ _s("권한") \
				+ "  • 인턴·주니어는 [b]PR을 올리고[/b] [b]리뷰 코멘트를 남길[/b] 수 있어요.\n  • [b]승인과 병합[/b]은 시니어(Daniel)만 할 수 있어요.\n" \
				+ _s("팁") + "  • 커밋 메시지는 %s %s %s %s 처럼 종류를 앞에 붙여요.\n  • 막히면 AICode의 [b]힌트[/b]를 써도 괜찮아요.\n" % [_c("fix:"), _c("feat:"), _c("docs:"), _c("test:")]
		"rules":
			if en:
				return _h("Team rules") \
					+ "  • [b]Never push to main directly.[/b] Branch → PR → senior approval → merge. (The remote main is protected.)\n" \
					+ "  • Bug-fix PRs include a [b]regression test[/b].\n" \
					+ "  • New features capture the spec's [b]boundary values[/b] in tests.\n" \
					+ "  • Every PR has a [b]description[/b]: what, why, how it was tested.\n" \
					+ "  • CI runs the team's tests plus [b][CI] extra checks[/b]. Red PRs can't be merged.\n" \
					+ "  • Reviewers compare the code with the Wiki and point at specific lines.\n" \
					+ "  • Retros are [b]blameless[/b]: fix the system, not the person.\n" \
					+ "  • AI-written code is reviewed and tested like any other code.\n" \
					+ "  • Give [b]realistic estimates[/b]. Over-promising hurts trust more than being honest.\n"
			return _h("협업 규칙") \
				+ "  • [b]main에 직접 push 금지[/b]. 작업 브랜치 → PR → 시니어 승인 → 병합. (원격 main은 보호되어 있음)\n" \
				+ "  • 버그 수정 PR에는 [b]회귀 테스트[/b]를 포함한다.\n" \
				+ "  • 새 기능은 스펙의 [b]경계값[/b]을 테스트로 남긴다.\n" \
				+ "  • 모든 PR에는 [b]설명[/b]을 적는다: 무엇을, 왜, 어떻게 테스트했는지.\n" \
				+ "  • CI는 팀 테스트 + [b][CI] 추가 검증 테스트[/b]를 실행한다. CI가 빨간 PR은 병합할 수 없다.\n" \
				+ "  • 리뷰어는 정책 문서(Wiki)와 코드를 대조하고, 문제 있는 줄을 짚어서 이야기한다.\n" \
				+ "  • 장애 회고는 [b]비난 없는 회고[/b]로 한다. 사람이 아니라 시스템을 고친다.\n" \
				+ "  • AI가 작성한 코드도 똑같이 리뷰하고 테스트한다.\n" \
				+ "  • 일정은 [b]현실적으로[/b] 말한다. 과한 약속은 솔직함보다 신뢰를 더 깎는다.\n"
		"names":
			if en:
				return _h("Display name rules") \
					+ "  1. Join firstName and lastName with a single space.\n" \
					+ "  2. Trim surrounding whitespace (including tabs and newlines) from each part.\n" \
					+ "  3. If only one part exists, show just that part. An empty string counts as missing.\n" \
					+ "  4. If both are empty, show %s.\n" % _c("\"Unknown User\"") \
					+ _s("Nickname (added in v0.15)") \
					+ "  5. If there is a nickname, show it instead of the name. Trim it too.\n" \
					+ "  6. A blank nickname counts as missing; fall back to rules 1-4.\n" \
					+ _s("Examples") \
					+ "  %s → Mina Choi\n  %s → Mina\n  %s → Unknown User\n  %s → soso\n" % [_c("{ firstName: ' Mina ', lastName: 'Choi' }"), _c("{ firstName: 'Mina', lastName: null }"), _c("{ firstName: '  ' }"), _c("{ nickname: ' soso ' }")]
			return _h("사용자 이름 표시 규칙") \
				+ "  1. firstName과 lastName을 공백 하나로 연결한다.\n" \
				+ "  2. 각 값의 앞뒤 공백(탭, 줄바꿈 포함)은 제거한다.\n" \
				+ "  3. 한쪽만 있으면 있는 쪽만 표시한다. 빈 문자열은 없는 것으로 본다.\n" \
				+ "  4. 둘 다 비어 있으면 %s를 표시한다.\n" % _c("\"Unknown User\"") \
				+ _s("닉네임 (v0.15 추가)") \
				+ "  5. 닉네임이 있으면 이름 대신 닉네임을 표시한다. 닉네임도 앞뒤 공백을 제거한다.\n" \
				+ "  6. 공백뿐인 닉네임은 없는 것으로 보고 1~4 규칙을 따른다.\n" \
				+ _s("예시") \
				+ "  %s → Mina Choi\n  %s → Mina\n  %s → Unknown User\n  %s → soso\n" % [_c("{ firstName: ' Mina ', lastName: 'Choi' }"), _c("{ firstName: 'Mina', lastName: null }"), _c("{ firstName: '  ' }"), _c("{ nickname: ' soso ' }")]
		"coupon":
			if en:
				return _h("Coupon policy") \
					+ "  • Coupon kinds: [b]percent[/b] %s and [b]amount[/b] %s\n" % [_c("{ type: 'percent', value }"), _c("{ type: 'amount', value }")] \
					+ "  • A percent coupon's value is a [b]percentage from 0 to 100[/b]. (10% coupon → value = 10)\n" \
					+ "  • Percent discounts [b]round down[/b] to whole won. (Math.floor)\n" \
					+ "  • An amount coupon's value is the discount in won.\n" \
					+ "  • The amount charged after a coupon [b]can never go below 0[/b].\n" \
					+ _s("Examples") \
					+ "  10,000 + 10% coupon → 9,000\n  2,000 + 5,000 amount coupon → 0\n  9,999 + 15% coupon → 8,500 (discount 1,499.85 → 1,499)\n"
			return _h("쿠폰 정책") \
				+ "  • 쿠폰 종류: [b]정률[/b] %s, [b]정액[/b] %s\n" % [_c("{ type: 'percent', value }"), _c("{ type: 'amount', value }")] \
				+ "  • 정률 쿠폰의 value는 [b]0~100 사이의 퍼센트[/b]다. (10% 쿠폰 → value = 10)\n" \
				+ "  • 정률 할인액은 원 단위 미만을 [b]버린다[/b]. (Math.floor)\n" \
				+ "  • 정액 쿠폰의 value는 원 단위 할인액이다.\n" \
				+ "  • 쿠폰을 적용한 결제 금액은 [b]0원 미만이 될 수 없다[/b].\n" \
				+ _s("예시") \
				+ "  10,000원 + 10% 쿠폰 → 9,000원\n  2,000원 + 5,000원 정액 쿠폰 → 0원\n  9,999원 + 15% 쿠폰 → 8,500원 (할인액 1,499.85 → 1,499)\n"
		"shipping":
			if en:
				return _h("Shipping policy (#004)") \
					+ "  • %s\n" % _c("shippingFee(subtotal, region = 'normal')") \
					+ "  • A subtotal of [b]50,000 or more[/b] ships free; below that the fee is [b]3,000[/b].\n" \
					+ "  • Remote areas %s always [b]add 5,000[/b], free shipping or not.\n" % _c("region = 'remote'") \
					+ "  • An empty order (subtotal 0) has no fee.\n" \
					+ "  • %s returns [b]subtotal + shipping[/b].\n" % _c("orderTotal(items, region = 'normal')") \
					+ _s("Examples") \
					+ "  49,999 → fee 3,000\n  50,000 → free\n  60,000 remote → 5,000\n  10,000 remote → 8,000 (order total 18,000)\n"
			return _h("배송비 정책 (#004)") \
				+ "  • %s\n" % _c("shippingFee(subtotal, region = 'normal')") \
				+ "  • 상품 합계가 [b]50,000원 이상[/b]이면 기본 배송비 무료, 미만이면 [b]3,000원[/b].\n" \
				+ "  • 도서산간 %s은 무료 배송 여부와 상관없이 [b]5,000원 추가[/b].\n" % _c("region = 'remote'") \
				+ "  • 상품 합계가 0원(빈 주문)이면 배송비 없음.\n" \
				+ "  • %s 는 [b]상품 합계 + 배송비[/b]를 반환한다.\n" % _c("orderTotal(items, region = 'normal')") \
				+ _s("예시") \
				+ "  49,999원 → 배송비 3,000원\n  50,000원 → 무료\n  60,000원 도서산간 → 5,000원\n  10,000원 도서산간 → 8,000원 (주문 합계 18,000원)\n"
		"auth":
			if en:
				return _h("Auth & incidents") \
					+ _s("login() spec") \
					+ "  • %s\n" % _c("login(authenticate, userId, timeoutMs = 5000)") \
					+ "  • If authenticate() doesn't answer within timeoutMs → %s.\n" % _c("Error('AUTH_TIMEOUT')") \
					+ "  • No token (null, empty) → %s. [b]Must be distinct from a timeout.[/b]\n" % _c("Error('AUTH_FAILED')") \
					+ "  • Errors thrown by the identity provider pass through [b]unchanged[/b].\n" \
					+ _s("Incident response") \
					+ "  1. Check the impact and logs in Monitor\n  2. Hypothesis → minimal fix (hotfix) → tests\n  3. PR → CI → merge → verify\n  4. Retro: prevention (blameless)\n"
			return _h("인증 / 장애 대응") \
				+ _s("login() 스펙") \
				+ "  • %s\n" % _c("login(authenticate, userId, timeoutMs = 5000)") \
				+ "  • authenticate()가 timeoutMs 안에 응답하지 않으면 %s 에러.\n" % _c("Error('AUTH_TIMEOUT')") \
				+ "  • 토큰이 없으면(null, 빈 문자열) %s 에러. [b]타임아웃과 구분해야 한다.[/b]\n" % _c("Error('AUTH_FAILED')") \
				+ "  • 인증 서버가 던진 에러는 [b]그대로[/b] 전달한다.\n" \
				+ _s("장애 대응 순서") \
				+ "  1. Monitor에서 영향 범위와 로그 확인\n  2. 원인 가설 → 최소 수정(핫픽스) → 테스트\n  3. PR → CI → 병합 → 배포 확인\n  4. 회고: 재발 방지책 정리 (비난 없는 회고)\n"
		"git":
			if en:
				return _h("Git cheat sheet") \
					+ _s("Look around") + "  %s  %s  %s  %s\n" % [_c("git status"), _c("git log --oneline"), _c("git diff"), _c("git show <commit>")] \
					+ _s("Find a cause") + "  %s — who changed each line and when\n  %s — a file's history with contents\n" % [_c("git blame <file>"), _c("git log -p <file>")] \
					+ _s("Branches") + "  %s  %s  %s\n" % [_c("git switch -c <new-branch>"), _c("git switch <branch>"), _c("git branch -d <branch>")] \
					+ _s("Sync") + "  %s — get remote changes\n  %s — bring main's changes into your branch\n" % [_c("git pull"), _c("git pull origin main")] \
					+ _s("Resolve a conflict") \
					+ "  1. %s, then find the conflicted files (%s)\n" % [_c("git pull origin main"), _c("git status")] \
					+ "  2. In DevIDE, clean up between %s — first ask whether both changes can be kept\n" % _c("<<<<<<<  =======  >>>>>>>") \
					+ "  3. %s → %s → %s → %s\n" % [_c("npm test"), _c("git add <file>"), _c("git commit --no-edit"), _c("git push")] \
					+ _s("Undo") + "  %s — discard unsaved edits\n  %s — a new commit that undoes one\n" % [_c("git restore <file>"), _c("git revert <commit> --no-edit")]
			return _h("Git 치트시트") \
				+ _s("상태 보기") + "  %s  %s  %s  %s\n" % [_c("git status"), _c("git log --oneline"), _c("git diff"), _c("git show <커밋>")] \
				+ _s("원인 찾기") + "  %s — 각 줄을 누가 언제 바꿨는지\n  %s — 파일의 변경 이력과 내용\n" % [_c("git blame <파일>"), _c("git log -p <파일>")] \
				+ _s("브랜치") + "  %s  %s  %s\n" % [_c("git switch -c <새브랜치>"), _c("git switch <브랜치>"), _c("git branch -d <브랜치>")] \
				+ _s("동기화") + "  %s — 원격 변경 받기\n  %s — main의 변경을 작업 브랜치로 가져오기\n" % [_c("git pull"), _c("git pull origin main")] \
				+ _s("충돌 해결") \
				+ "  1. %s 후 충돌 파일 확인 (%s)\n" % [_c("git pull origin main"), _c("git status")] \
				+ "  2. DevIDE에서 %s 표시 사이를 정리 — 두 변경을 모두 살릴 수 있는지 먼저 생각하기\n" % _c("<<<<<<<  =======  >>>>>>>") \
				+ "  3. %s → %s → %s → %s\n" % [_c("npm test"), _c("git add <파일>"), _c("git commit --no-edit"), _c("git push")] \
				+ _s("되돌리기") + "  %s — 저장 안 한 변경 버리기\n  %s — 커밋을 되돌리는 새 커밋\n" % [_c("git restore <파일>"), _c("git revert <커밋> --no-edit")]
	return ""
