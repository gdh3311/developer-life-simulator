extends RefCounted
## Side-ticket board: small real bugs teammates hand you between main tasks (5–15 minutes each).
## Taking one pushes a module and a failing public test to main; you fix it on ticket/<id>, open a PR,
## pass hidden CI and the requester reviews and merges. Each finished ticket gets a scorecard compared
## with a fixed team distribution (Exapunks-style), so a ticket is worth redoing better.
## State: Game.state["tickets"] = { active, started, ci_runs, base_tests, pr, done: {id: record}, taken: {day: n} }

const PER_DAY := 2

## [id, module, chapter it unlocks, requester, par minutes, reward, title, request]
const LIST := [
	["t01", "slug", 2, "sophie", 25, 15000, {"ko": "상품 주소에 공백이 남아요", "en": "Spaces left in product URLs"},
		{"ko": "상품 이름에 공백이 두 개 있으면 주소가 깨져요. 'Spring  Tea'가 'spring--tea'가 돼요.", "en": "Product names with double spaces break the URL. 'Spring  Tea' turns into 'spring--tea'."}],
	["t03", "mask_phone", 2, "yuri", 20, 15000, {"ko": "영수증에 전화번호가 다 보여요", "en": "Receipts show the whole phone number"},
		{"ko": "고객 영수증에 번호 끝자리만 가려져요. 가운데를 가려야 해요. 개인정보 문의가 들어왔어요.", "en": "Receipts hide only the last digits. It should be the middle. We got a privacy complaint."}],
	["t05", "csv_row", 2, "yuri", 25, 18000, {"ko": "주문 내보내기가 엑셀에서 깨져요", "en": "Order export breaks in Excel"},
		{"ko": "판매자가 내려받은 CSV에서 '녹차, 대용량' 같은 상품명이 두 칸으로 갈라져요.", "en": "In the sellers' CSV export, product names like 'green tea, large' split into two columns."}],
	["t11", "stock_badge", 2, "mina", 15, 12000, {"ko": "품절인데 '품절 임박'이래요", "en": "Sold out says 'almost gone'"},
		{"ko": "재고 0개인 상품 카드에 '품절 임박' 배지가 떠요. 고객이 계속 눌러 봐요.", "en": "Product cards with zero stock show 'almost gone'. Customers keep tapping them."}],
	["t02", "page_range", 3, "sophie", 25, 18000, {"ko": "마지막 페이지에 빈 줄이 보여요", "en": "Empty rows on the last page"},
		{"ko": "주문 목록 마지막 페이지가 '21–30번'이라고 나오는데 실제론 25건뿐이에요.", "en": "The last page of the order list says 'rows 21–30', but there are only 25 orders."}],
	["t07", "backoff", 3, "daniel", 15, 15000, {"ko": "알림 재시도가 몇 시간씩 기다려요", "en": "Notification retries wait for hours"},
		{"ko": "알림 발송 재시도 간격이 계속 두 배가 돼서 열 번째엔 17분을 기다려요. 30초 상한이 있었는데 빠졌네요.", "en": "Retry delays keep doubling; the tenth waits 17 minutes. There used to be a 30-second cap."}],
	["t09", "search_match", 3, "yuri", 25, 18000, {"ko": "'green tea'로 검색이 안 돼요", "en": "Searching 'green tea' finds nothing"},
		{"ko": "고객이 소문자로 'green tea'를 검색하면 'Green Tea Set'이 안 나와요.", "en": "Searching 'green tea' in lower case doesn't find 'Green Tea Set'."}],
	["t12", "rating", 3, "sophie", 20, 15000, {"ko": "리뷰 없는 상품에 별점 NaN", "en": "NaN stars on products without reviews"},
		{"ko": "리뷰가 없는 새 상품 페이지에 '별점 NaN'이라고 떠요. 캡처가 커뮤니티에 돌고 있어요ㅠ", "en": "New products with no reviews show 'NaN stars'. Screenshots are going around ㅠ"}],
	["t04", "ship_date", 4, "mina", 30, 20000, {"ko": "주말에도 배송한다고 나와요", "en": "Ship-by dates land on weekends"},
		{"ko": "금요일 주문의 '1영업일 내 발송'이 토요일로 표시돼요. 택배사는 주말에 안 와요.", "en": "A Friday order's '1 business day' ship-by shows Saturday. The courier doesn't come on weekends."}],
	["t06", "coupon_expiry", 4, "alex", 30, 20000, {"ko": "쿠폰이 마지막 날 아침에 만료돼요", "en": "Coupons expire on the morning of their last day"},
		{"ko": "'3월 31일까지' 쿠폰이 31일 오전 9시에 이미 안 써져요. 고객은 31일 밤까지라고 알고 있어요.", "en": "A coupon 'valid through Mar 31' stops working at 9 a.m. on the 31st. Customers expect it to last all day."}],
	["t08", "vat", 4, "alex", 25, 20000, {"ko": "부가세가 정산표와 몇 원씩 달라요", "en": "VAT is off by a few won from finance"},
		{"ko": "정산팀이 부가세 합계가 몇 원씩 다르대요. 정책은 합계에서 한 번만 내림이에요.", "en": "Finance says VAT totals are a few won off. The policy is to round down once, on the total."}],
	["t10", "email", 4, "mina", 20, 15000, {"ko": "'+' 들어간 이메일로 가입이 안 돼요", "en": "Sign-up rejects emails with '+'"},
		{"ko": "me+shop@mail.com 같은 주소로 가입이 막혀요. 회사 도메인(co.kr)도 안 된대요.", "en": "Addresses like me+shop@mail.com can't sign up. Company domains (co.kr) fail too."}],
]


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	if not Game.state.has("tickets") or typeof(Game.state["tickets"]) != TYPE_DICTIONARY:
		Game.state["tickets"] = {"active": "", "done": {}, "taken": {}}
	return Game.state["tickets"]


func row(id: String) -> Array:
	for r in LIST:
		if r[0] == id:
			return r
	return []


func unlocked(id: String) -> bool:
	var r := row(id)
	return not r.is_empty() and Game.chapter() >= int(r[2])


func is_done(id: String) -> bool:
	return (st()["done"] as Dictionary).has(id)


func active() -> String:
	return String(st().get("active", ""))


func taken_today() -> int:
	return int((st()["taken"] as Dictionary).get(str(Game.day()), 0))


## Tickets on the board right now (unlocked, not done).
func board() -> Array:
	return LIST.filter(func(r: Array) -> bool: return unlocked(r[0]) and not is_done(r[0])).map(func(r: Array) -> String: return r[0])


func progress() -> Dictionary:
	var open := LIST.filter(func(r: Array) -> bool: return unlocked(r[0])).size()
	return {"done": (st()["done"] as Dictionary).size(), "unlocked": open, "total": LIST.size()}


func can_take(id: String) -> String:
	if not unlocked(id) or is_done(id):
		return "locked"
	if active() != "":
		return "busy"
	if taken_today() >= PER_DAY:
		return "daily"
	if not (Workspace.is_ready and Workspace.exists()):
		return "workspace"
	return ""


static func test_path(module: String) -> String:
	return "tests/ticket_%s.test.ts" % module


static func src_path(module: String) -> String:
	return "src/tickets/%s.ts" % module


## Takes a ticket: the requester pushes the module and a failing public test to main.
func take(id: String) -> bool:
	if can_take(id) != "":
		return false
	var r := row(id)
	var s := st()
	s["active"] = id
	s["started"] = Game.day() * 1440 + Game.minutes()
	s["ci_runs"] = 0
	s["pr"] = 0
	var taken: Dictionary = s["taken"]
	taken[str(Game.day())] = taken_today() + 1
	var test_body := Workspace.content("tickets/%s.test.ts" % id).replace("../src/tickets/", "../src/tickets/")
	s["base_tests"] = test_body.count("test(")
	Game.save_soon()
	var ok: bool = await Workspace.bot_commit(_committer(r[3]), "main", {
		src_path(r[1]): Workspace.content("tickets/%s.ts" % id),
		test_path(r[1]): test_body,
	}, "chore(tickets): %s — %s" % [id, Game.tx(r[6])])
	Game.say(r[3], {"ko": "🎫 작은 부탁 하나요: %s\nmain에 재현 테스트 올렸어요. 브랜치는 ticket/%s로 해 주세요." % [r[7]["ko"], id],
		"en": "🎫 A small favor: %s\nI pushed a reproducing test to main. Please use the branch ticket/%s." % [r[7]["en"], id]})
	Game.emit_event("ticket_taken", {"ticket": id})
	return ok


## Only teammates with a Git identity commit; customer-facing requests arrive through Yuri but Sophie commits.
static func _committer(who: String) -> String:
	return who if who in ["daniel", "sophie", "mina", "alex"] else "sophie"


func drop() -> void:
	var id := active()
	if id == "":
		return
	st()["active"] = ""
	Game.say(row(id)[3], t("괜찮아요, 그 건은 제가 나중에 볼게요.", "No worries, I'll look at that one later."))
	Game.emit_event("ticket_dropped", {"ticket": id})


## Called by Story.claim_pr: a PR from ticket/<id> belongs to the board, never to the main task.
func claim(pr: Dictionary) -> bool:
	var branch := String(pr.get("branch", ""))
	if not branch.begins_with("ticket/"):
		return false
	var id := active()
	if id == "" or branch != "ticket/" + id:
		return true  # still not a mission PR
	st()["pr"] = int(pr["id"])
	pr["mission"] = "ticket:" + id
	pr["reviewer"] = _committer(row(id)[3])
	pr["review"]["by"] = pr["reviewer"]
	return true


func hidden_tests(mission_key: String) -> Dictionary:
	var id := mission_key.trim_prefix("ticket:")
	var result := {}
	var dir := Workspace.ci_content_dir("tk_" + id)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ts"):
			result[f] = FileAccess.get_file_as_string(dir.path_join(f))
	return result


func on_event(kind: String, d: Dictionary) -> void:
	var id := active()
	if id == "":
		return
	var pr_id := int(st().get("pr", 0))
	match kind:
		"ci":
			if int(d.get("pr", 0)) != pr_id:
				return
			st()["ci_runs"] = int(st().get("ci_runs", 0)) + 1
			var p := CodeHub.get_pr(pr_id)
			if d.get("ok", false) and p["review"]["state"] == "pending" and not d.get("conflict", false):
				CodeHub.review(pr_id, String(p["reviewer"]), "approved", t("고마워요! 테스트까지 확인했어요.", "Thanks! Tests checked too."))
			elif not d.get("ok", false) and int(st()["ci_runs"]) == 1:
				CodeHub.comment(pr_id, String(p["reviewer"]), t("CI에 [CI] 검증이 두 개 더 있어요. 실패한 이름을 보면 빠진 경우가 보여요.", "CI has two more [CI] checks. The failing names show which case is missing."))
		"pr_merged":
			if int(d.get("pr", 0)) == pr_id:
				_finish(id)


func _finish(id: String) -> void:
	var r := row(id)
	var s := st()
	var minutes := maxi(1, Game.day() * 1440 + Game.minutes() - int(s.get("started", 0)))
	var tests := Workspace.read_file(test_path(r[1])).count("test(") if FileAccess.file_exists(Workspace.resolve(test_path(r[1]))) else 0
	var record := {"minutes": minutes, "ci_runs": int(s.get("ci_runs", 1)), "tests_added": maxi(0, tests - int(s.get("base_tests", 0))), "day": Game.day()}
	(s["done"] as Dictionary)[id] = record
	s["active"] = ""
	s["pr"] = 0
	Game.earn(int(r[5]))
	Game.relate(r[3], {"close": 2, "work": 1})
	var rank := percentile(id, minutes)
	Game.say(r[3], {"ko": "고쳐 줘서 고마워요! 🙏 (%d분 · CI %d번 · %s)" % [minutes, record["ci_runs"], standing(rank)["ko"]],
		"en": "Thanks for fixing it! 🙏 (%d min · %d CI runs · %s)" % [minutes, record["ci_runs"], standing(rank)["en"]]})
	Game.notify("tasks", Game.L("작은 일감 완료", "Ticket done"), "%s · +%s" % [Game.tx(r[6]), Game.won(int(r[5]))])
	Game.emit_event("ticket_done", {"ticket": id, "minutes": minutes, "tests_added": record["tests_added"]})
	Game.save_soon()


## The team's (fictional, fixed) times for this ticket: 20 values around its par.
func team_times(id: String) -> Array:
	var r := row(id)
	var par := int(r[4]) if not r.is_empty() else 20
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var out: Array = []
	for i in 20:
		# Par is relative difficulty; real tickets take ~40-90 in-game minutes (each command advances the clock).
		out.append(maxi(10, roundi(par * 2.6 * rng.randf_range(0.6, 1.9))))
	out.sort()
	return out


## How your time reads next to the team's.
static func standing(pct: int) -> Dictionary:
	if pct >= 50:
		return {"ko": "팀의 %d%%보다 빠름" % pct, "en": "faster than %d%% of the team" % pct}
	if pct > 0:
		return {"ko": "팀 중간보다 조금 느림", "en": "a little slower than the team's middle"}
	return {"ko": "팀 기록보다 오래 걸림 — 다음엔 더 빨리", "en": "slower than the team's times — next time, faster"}


## Percent of the team that took longer than you (higher is better).
func percentile(id: String, minutes: int) -> int:
	var times := team_times(id)
	var slower := times.filter(func(x: int) -> bool: return x > minutes).size()
	return roundi(100.0 * slower / times.size())
