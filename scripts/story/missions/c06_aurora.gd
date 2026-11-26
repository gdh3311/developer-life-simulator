extends "res://scripts/story/mission.gd"
## An order handover seen from either end of the contract.

const Transfer := preload("res://scripts/services/aurora_transfer.gd")
const CONTENT := "res://content/transfer/"
const CASES := [
	["달라진 출입증", "A different badge", "chat", "access", "팀의 첫 메시지에 답장하기", "Reply to your team's first message"],
	["내보내는 사람, 받는 사람", "Sending and receiving", "ide", "merged", "어댑터 수정 PR을 검토받고 병합하기", "Get the adapter fix reviewed and merged"],
	["숫자는 같은데 사람이 다르다", "Same number, different seller", "browser", "match", "Relay에서 두 주문을 판매자 계정에 연결하기", "Match both orders to their seller accounts in Relay"],
	["이 일은 우리 팀 건가요", "Is this our team's ticket?", "docs", "ownership", "Docs에 양쪽 담당과 보류 기준 남기기", "Record owners on both sides and when to hold in Docs"],
	["되돌릴 수 있는 이관", "A reversible transfer", "browser", "rehearse", "Relay에서 이관과 원복 뒤 누락이 없는지 확인하기", "Verify that both cutover and rollback preserve orders in Relay"],
	["예전 동료에게 보내는 요청", "A request across the table", "chat", "handover", "상대 회사에 이관 결과와 다음 일정을 전하기", "Share the transfer result and next steps with the other company"],
]

var _step: int


func _init(step: int) -> void:
	_step = step
	id = "c06_%02d" % (step + 1)
	chapter = 6
	day = 17 if step < 3 else 18
	issue = "AUR-%03d" % (71 + step)
	var row: Array = CASES[step]
	title = t(row[0], row[1])
	objectives = [{"id": row[3], "app": row[2], "text": t(row[4], row[5])}]
	if step == 1:
		objectives.push_front({"id": "pr", "app": "codehub", "text": t("CodeHub에 수정 PR 제출하기", "Open the adapter PR in CodeHub")})
		objectives.insert(1, {"id": "ci", "app": "codehub", "text": t("추가 CI 검증 통과하기", "Pass the additional CI checks")})
	if step == 3:
		_build()


func _build() -> void:
	forms_def["ownership"] = {
		"title": t("오로라 리테일 · 양사 이관 담당", "Aurora Retail · migration ownership"),
		"intro": t("두 회사가 같은 접수표를 봅니다. 매핑을 고칠 팀과 이관을 멈추는 기준을 미리 적어 두세요.",
			"Both companies share this ticket. Record who corrects each mapping and when to pause the transfer."),
		"submit": t("공용 접수표에 저장", "Save to the shared ticket"),
		"slots": [
			_slot("exporter", t("내부 판매자 코드가 잘못 내보내졌을 때", "When the exporter sends the wrong seller code"), [
				["nexora", t("NEXORA · Mina", "NEXORA · Mina")], ["brightloop", t("Brightloop · Raon", "Brightloop · Raon")]]),
			_slot("importer", t("올바른 공용 코드가 잘못된 계정에 연결될 때", "When a correct shared code resolves to the wrong account"), [
				["nexora", t("NEXORA · Mina", "NEXORA · Mina")], ["brightloop", t("Brightloop · Raon", "Brightloop · Raon")]]),
			_slot("stop", t("전환 보류 기준", "Hold criterion"), [
				["missing", t("판매자별 주문이 한 건이라도 빠지면 보류", "Hold if even one seller's order is missing")],
				["count", t("전체 주문 수만 같으면 진행", "Proceed if the total order count matches")]]),
		],
	}


func _slot(key: String, label: Dictionary, values: Array) -> Dictionary:
	return {"id": key, "label": label, "options": values.map(func(v: Array) -> Dictionary: return {"id": v[0], "text": v[1]})}


func _relay_link() -> Dictionary:
	return {"link": {"app": "browser", "target": Transfer.ROUTE, "label": t("Relay에서 이관 작업대 열기", "Open the transfer desk in Relay")}}


func begin() -> void:
	var lead := Transfer.contact()
	Game.add_issue(issue, title, ["task", "feature", "bug", "docs", "task", "task"][_step], Game.L("나", "me"), "progress")
	match _step:
		0:
			if Transfer.moved():
				say("recruiter", t("Brightloop 첫날이에요. 인수팀의 Raon이 오로라 리테일 표본 저장소 접근을 승인했어요.", "It's your first day at Brightloop. Raon on the receiving team approved access to the Aurora Retail sample repository."))
			else:
				say("mina", t("플랫폼팀으로 옮겨도 층은 그대로예요. 오로라 리테일 주문은 우리가 Brightloop에 내보내기로 했고요.", "The platform team still sits on this floor. We're sending Aurora Retail's orders to Brightloop."))
			_handoff_note()
			choice(lead, t("양사 공용 표본으로 먼저 확인해요. 어느 쪽을 맡게 됐는지 답장해 주세요.", "Let's work with the shared sample first. Which side are you taking?"), "c06_access", [
				["work", t("인수 어댑터를 맡을게요. Brightloop 계정 매핑부터 확인하겠습니다.", "I'll take the importer and start with the Brightloop account mapping.")]
					if Transfer.moved() else ["work", t("내보내기를 맡을게요. NEXORA 판매자 코드부터 확인하겠습니다.", "I'll take the exporter and start with the NEXORA seller codes.")],
				["pair", t("첫 표본 한 건을 같이 볼 수 있을까요?", "Can we look at the first sample together?")],
			], _relay_link())
		1:
			await _prepare_adapter()
		2:
			say(Transfer.partner(), t("ORD-104가 두 줄인데 금액이 달라요. 삭제하기 전에 Relay에서 공용 판매자 코드와 인수 계정을 한 줄씩 대조해 주세요.",
				"ORD-104 appears twice with different amounts. Before deleting anything, match each shared seller code to its receiving account in Relay."), _relay_link())
		3:
			say(lead, t("어제 찾은 두 주문을 기준으로 연락처를 정해요. 각 팀이 고칠 수 있는 매핑이 달라요. Docs의 공용 접수표를 채워 주세요.",
				"Use the two orders you found yesterday to agree on contacts. Each team owns a different mapping. Fill in the shared ticket in Docs."),
				{"link": {"app": "docs", "label": t("Docs 열기", "Open Docs")}})
		4:
			say(lead, t("복제본을 뜨고 나서도 주문은 들어와요. 전환 직전 주문과 원복 직전 주문이 모두 살아 있는지 작업대에서 리허설해 주세요.",
				"Orders keep coming after a snapshot. Rehearse at the transfer desk and verify that the order before cutover and the one before rollback both survive."), _relay_link())
		5:
			choice(Transfer.partner(), t("양쪽 주문을 맞췄고 원복도 확인했어요. 금요일 파일럿을 잡을까요, 판매자 확인 뒤 월요일로 잡을까요?",
				"We reconciled both sides and verified rollback. Book Friday's pilot or wait until Monday for seller sign-off?"), "c06_handover", [
				["friday", t("금요일 한 판매자부터. 양쪽 담당이 창을 확인한 뒤 진행합니다.", "Start with one seller on Friday after both owners confirm the window.")],
				["monday", t("판매자 확인을 받은 뒤 월요일에 엽니다.", "Open on Monday after the seller signs off.")],
			], _relay_link())


func _handoff_note() -> void:
	var flags: Dictionary = Game.state["flags"]
	var handoff: Dictionary = flags.get("c05_handoff", {})
	if Transfer.moved() and handoff.has("atlas"):
		var owner := Game.npc_name(String(handoff["atlas"]))
		say("sophie", t("ATLAS 재처리 목록은 %s 님이 인계받았어요. Aurora에서는 공용 접수표로 만나요." % owner,
			"%s took over the ATLAS retry list. I'll see you on Aurora's shared ticket." % owner))
	elif flags.get("c05_overload", false):
		say("daniel", t("지난번 두 업무 다 가져갔죠. 그 일정은 다음 주로 미뤘어요. 오늘은 오로라만 맡아 주세요.",
			"You took both campaign tasks. I moved them to next week so you can focus on Aurora today."))
	elif handoff.has("qa_check"):
		var owner := Game.npc_name(String(handoff["qa_check"])) if handoff["qa_check"] != "me" else Game.pname()
		say("mina", t("캠페인 QA 체크리스트는 %s 님이 맡은 걸로 명단에 올렸어요." % owner, "%s is on the rota for the campaign QA checklist." % owner))


func _adapter() -> String:
	return "import_orders" if Transfer.moved() else "export_orders"


func _prepare_adapter() -> void:
	var name := _adapter()
	var path := "src/transfer/" + name + ".ts"
	var actor := Transfer.contact()
	default_reviewer = "raon" if Transfer.moved() else "daniel"
	if not data().get("_prepared", false):
		var files := {path: FileAccess.get_file_as_string(CONTENT + name + ".ts"),
			"tests/" + name + ".test.ts": FileAccess.get_file_as_string(CONTENT + name + ".test.ts")}
		var ready := await Workspace.bot_commit(actor, "main", files, "feat(aurora): prepare shared " + name + " sample")
		if not is_current():
			return
		# A reload can interrupt after the commit has already reached the remote.
		if not ready:
			var remote := await Workspace._git_in(Workspace.origin, ["show", "main:" + path])
			if not is_current():
				return
			ready = remote["code"] == 0 and String(remote["out"]).strip_edges() == String(files[path]).strip_edges()
		if not ready:
			if not Game.pending_choice("c06_retry_adapter"):
				Game.say(actor, t("표본을 올리지 못했어요. 저장소가 준비되면 아래 버튼으로 다시 시도해 주세요.",
					"Couldn't publish the sample. Once the workspace is ready, use the button below to retry."),
					{"key": "c06_retry_adapter", "choices": [{"id": "retry", "label": t("표본 다시 받기", "Retry sample setup")}]})
			return
		data()["_prepared"] = true
		Game.save_soon()
	_set_adapter_help(path)
	say(actor, t("공용 저장소의 main을 Pull한 뒤 %s를 고쳐 주세요. Relay 작업대에 계약과 표본이 있어요. 작업 브랜치에서 테스트하고 PR을 올려 주세요." % path,
		"Pull main, then edit %s. The contract and samples are in Relay. Test on a working branch and open a PR." % path), _relay_link())


func _set_adapter_help(path: String) -> void:
	if Transfer.moved():
		hints = [t("version 1과 알려진 판매자만 적용하세요. 같은 orderId라도 계정이 다르면 다른 주문이에요.",
			"Apply version 1 and known sellers only. The same orderId on a different account is a different order."),
			t("accountId와 orderId를 묶어 Map의 키로 사용하세요. 같은 키의 나중 값으로 덮어써요.",
				"Use accountId and orderId together as the Map key and overwrite it with the latest delivery.")]
		ai_task = {"label": t("인수 어댑터 초안", "Importer draft"),
			"substitution": {"path": path,
				"from": "return orders.map((order) => ({\n    accountId: order.sellerCode,\n    orderId: order.orderId,\n    totalWon: order.totalWon,\n    refundedWon: order.refundedWon,\n  }));",
				"to": "const rows = new Map();\n  for (const order of orders) {\n    rows.set(order.orderId, {\n      accountId: sellerIds[order.sellerCode],\n      orderId: order.orderId,\n      totalWon: order.totalWon,\n      refundedWon: order.refundedWon,\n    });\n  }\n  return [...rows.values()];"},
			"summary": t("계정 매핑과 재전송 덮어쓰기를 넣었습니다. 여러 판매자가 섞인 배치와 버전 검증은 확인하지 않았습니다.",
				"Mapped accounts and added overwrite on repeat delivery. Mixed-seller batches and version validation are unverified.")}
	else:
		hints = [t("sellerCodes에서 order.shop의 공용 코드를 찾고, 없으면 null을 반환하세요.", "Look up order.shop in sellerCodes and return null when no mapping exists."),
			t("refundedWon이 null이거나 undefined일 때만 0으로 바꾸세요.", "Use zero only when refundedWon is null or undefined.")]
		ai_task = {"label": t("내보내기 어댑터 초안", "Exporter draft"),
			"substitution": {"path": path,
				"from": "sellerCode: order.shop,\n    orderId: order.id,\n    totalWon: order.totalWon,\n    refundedWon: order.refundedWon,",
				"to": "sellerCode: sellerCodes[order.shop],\n    orderId: order.id,\n    totalWon: order.totalWon,\n    refundedWon: order.refundedWon ?? 0,"},
			"summary": t("공용 판매자 코드와 환불 기본값을 적용했습니다. 매핑이 없는 판매자는 검증하지 않았습니다.",
				"Applied shared seller codes and the refund default. Unmapped sellers are unverified.")}


func resume() -> void:
	if _step == 1 and not all_done():
		await _prepare_adapter()
		if is_current():
			super.resume()
	else:
		super.resume()


func hidden_tests() -> Dictionary:
	if _step != 1:
		return {}
	var variant := "import" if Transfer.moved() else "export"
	return {"aurora_ci.test.ts": FileAccess.get_file_as_string(CONTENT + variant + "_ci.test.ts")}


func review(p: Dictionary) -> void:
	if _step != 1 or not data().get("_prepared", false):
		return
	CodeHub.review(p["id"], default_reviewer, "approved", t("두 판매자가 같은 주문 번호를 쓰는 표본으로 확인했습니다. 공용 이관 작업대에서 한 줄씩 대조해 주세요.",
		"Checked the sample where both sellers have the same order number. Please reconcile both rows in the shared transfer desk."))


func judge_form(_form_id: String, picks: Dictionary) -> Array:
	var notes := []
	if FormRules.picked(picks, "exporter")[0] != "nexora":
		notes.append(t("Mina: 공용 코드를 만드는 쪽은 NEXORA예요. 내보낸 값부터 저한테 보내 주세요.", "Mina: NEXORA produces the shared code. Send the exported value to me first."))
	if FormRules.picked(picks, "importer")[0] != "brightloop":
		notes.append(t("Raon: 인수 계정은 Brightloop 쪽에서 정해요. 코드가 맞으면 제가 계정 매핑을 봅니다.", "Raon: Brightloop owns receiving accounts. If the code is correct, I'll check the account mapping."))
	if FormRules.picked(picks, "stop")[0] != "missing":
		notes.append(t("전체 건수가 맞아도 판매자 두 곳의 주문이 서로 바뀔 수 있어요.", "The total can be right even when two sellers' orders are swapped."))
	return notes


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	doc_comment("ownership", Transfer.partner(), t("담당 두 명 확인했습니다. 누락이 보이면 접수표에 주문 키를 남기고 전환을 보류해요.",
		"Confirmed both owners. If a row is missing, record its order key here and hold the cutover."))
	_close("ownership")


func on_event(kind: String, d: Dictionary) -> void:
	match _step:
		0:
			if kind == "choice" and d.get("key") == "c06_access":
				if d["option"] == "pair":
					say(Transfer.contact(), t("NX-41과 BL-713은 양쪽 시스템의 이름이에요. 둘을 이어 주는 건 AUR-01입니다. 나머지 한 줄은 직접 볼까요?",
						"NX-41 and BL-713 are the local account names. AUR-01 links them. Can you check the other row?"))
				_close("access")
		1:
			if kind == "choice" and d.get("key") == "c06_retry_adapter" and not data().get("_prepared", false):
				_prepare_adapter()
			elif kind == "pr_merged" and int(d["pr"]) == int(data().get("pr", -1)):
				_close("merged")
		2:
			if kind == "aurora_matched":
				say(Transfer.partner(), t("같은 주문 번호를 각자의 고객이 쓰고 있었군요. 보고서에 두 줄 다 남길게요.",
					"Two customers really do use the same order number. I'll keep both rows in the report."))
				_close("match")
		4:
			if kind == "aurora_rehearsed":
				_close("rehearse")
		5:
			if kind == "choice" and d.get("key") == "c06_handover":
				_handover(String(d["option"]))


func _handover(window: String) -> void:
	Game.state["flags"]["c06_pilot_window"] = window
	if window == "friday":
		say(Transfer.partner(), t("금요일 10시, AUR-01만 열죠. Mina와 Raon이 첫 주문과 다음 동기화 시각을 공용 접수표에 적겠습니다.",
			"Friday, 10 a.m., AUR-01 only. Mina and Raon will log the first order and the next sync in the shared ticket."))
	else:
		say(Transfer.partner(), t("월요일로 잡죠. 제가 판매자 확인을 받아 둘게요. 금요일 주문은 지금 방식으로 계속 처리됩니다.",
			"Monday then. I'll get the seller's sign-off. Friday's orders will keep going through the existing flow."))
	if Transfer.moved():
		say("sophie", t("업무상으로는 첫 공식 요청이네요. 개인적으로는… 금요일 점심 아직 비워 뒀어요.",
			"That's our first official request across companies. Personally... I still have Friday lunch free."))
	else:
		say("mina", t("계약서는 보냈고, 새 플랫폼팀 사람들이 점심 먹재요. 같이 가요. 식당은 그대로예요.",
			"Contract sent. The new platform team is going to lunch. Come with us. Same restaurant."))
	Game.set_time(18 * 60)
	_close("handover")


func _close(objective: String) -> void:
	complete(objective)
	Game.advance(10)
	finish()
