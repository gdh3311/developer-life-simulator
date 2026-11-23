extends RefCounted
## Case content and matching rules. Observations are earned from actual tool results.


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


static func clue(id: String, title: Dictionary, detail: Dictionary, source: String, target: String, app: String, action: Dictionary) -> Dictionary:
	return {"id": id, "title": title, "detail": detail, "source": source, "target": target, "app": app, "action": action}


static func definitions() -> Dictionary:
	var names := clue("policy", t("이름 표시 정책", "Name policy"), t("이름의 공백을 제거하고, 값이 없으면 남은 이름 또는 기본 이름으로 표시해야 한다.", "Trim name parts; missing values fall back to the remaining part or the default name."), "wiki_page", "names", "wiki", t("Wiki에서 이름 정책 읽기", "Read the name policy in Wiki"))
	var failed := clue("reproduction", t("실패를 재현한 테스트", "A failing reproduction"), t("실제 로컬 테스트에서 실패를 확인했다. 실패한 입력과 기대 결과를 비교할 수 있다.", "A local test failed. Compare its input with the expected result in Terminal."), "tests_failed", "", "terminal", t("Terminal에서 npm test 실행", "Run npm test in Terminal"))
	var coupon := clue("policy", t("쿠폰의 단위와 하한", "Coupon units and lower bound"), t("value=10은 10%다. 할인액은 버리고, 최종 결제 금액은 0원보다 작을 수 없다.", "value=10 means 10%. Round the discount down; the final charge cannot be negative."), "wiki_page", "coupon", "wiki", t("Wiki에서 쿠폰 정책 읽기", "Read the coupon policy in Wiki"))
	return {
		"d2_04": {
			"question": t("왜 이름에 undefined가 보일까?", "Why does a name show undefined?"),
			"clues": [names, failed, clue("code", t("이름을 합치는 코드", "The name formatter"), t("displayName은 입력 이름을 합쳐 화면 문자열을 만든다. 빠진 값과 공백을 어떻게 처리하는지 살펴보자.", "displayName joins input names into a label. Check how it handles missing values and whitespace."), "code_viewed", "src/users/displayName.ts", "ide", t("DevIDE에서 displayName.ts 열기", "Open displayName.ts in DevIDE"))],
			"hypotheses": [
				{"id": "cache", "text": t("화면에 예전 이름이 캐시돼 있다", "The screen cached an old name")},
				{"id": "optional", "text": t("누락된 값을 그대로 문자열로 합친다", "Missing values are joined into the string")},
				{"id": "encoding", "text": t("API와 화면이 서로 다른 이름 필드 키를 쓴다", "The API and screen use different name-field keys")},
			], "answer": "optional",
			"lesson": t("누락된 값과 공백은 서로 다른 입력이다. 둘 다 정리한 뒤 남은 값으로 이름을 만들면 undefined를 숨기는 것보다 튼튼한 수정이 된다.", "Missing values and whitespace are different inputs. Normalize both, then join the remaining parts instead of merely hiding undefined."),
		},
		"d2_05": {
			"question": t("어제 고친 버그가 왜 다시 나타났을까?", "Why did yesterday's bug return?"),
			"clues": [names, failed, clue("history", t("최근 변경의 흔적", "Recent change history"), t("이름 처리 코드의 실제 Git 기록을 확인했다. 새 닉네임 경로가 기존 이름 규칙을 유지하는지 비교하자.", "You inspected real Git history for the name formatter. Check whether the new nickname path preserves the original rules."), "history", "displayName", "terminal", t("git log -p 또는 git blame src/users/displayName.ts", "Use git log -p or git blame src/users/displayName.ts"))],
			"hypotheses": [
				{"id": "nickname", "text": t("닉네임 경로가 기존 이름의 예외 처리를 놓쳤다", "The nickname path lost the original fallback rules")},
				{"id": "remove", "text": t("이름과 닉네임의 표시 우선순위만 거꾸로 됐다", "Only the display priority of names and nicknames is reversed")},
				{"id": "server", "text": t("배포 후 프로필 캐시에 옛 결과가 남았다", "The profile cache retained old results after deployment")},
			], "answer": "nickname",
			"lesson": t("회귀 수정은 새 기능을 지우는 일이 아니다. 닉네임을 살리면서 기존 이름 규칙도 지키는 테스트가 다음 변경의 안전망이 된다.", "A regression fix should preserve the new feature and the old contract. Tests for both protect the next change."),
		},
		"d3_06": {
			"question": t("초록색 CI인데 쿠폰 계산도 맞을까?", "CI is green. Is the coupon math correct?"),
			"clues": [coupon, clue("diff", t("쿠폰 PR의 변경 사항", "The coupon PR diff"), t("실제 쿠폰 PR의 diff를 열었다. 할인 단위와 결제 금액의 하한을 정책 예시와 비교할 수 있다.", "You opened the real coupon PR diff. Compare the discount units and final-charge bounds with the policy examples."), "pr_diff_viewed", "d3_06", "codehub", t("CodeHub에서 쿠폰 PR의 변경 사항 열기", "Open the coupon PR's Changes in CodeHub")), clue("code", t("쿠폰 코드 직접 읽기", "Reading the coupon code"), t("현재 브랜치의 쿠폰 함수를 읽었다. 리뷰 대상 PR과 같은 버전인지는 diff에서도 확인하자.", "You read the coupon function on your branch. Check the PR diff to confirm you reviewed the same version."), "code_viewed", "src/orders/coupon.ts", "ide", t("DevIDE에서 coupon.ts 열기", "Open coupon.ts in DevIDE"))],
			"hypotheses": [
				{"id": "gateway", "text": t("같은 주문에 할인이 두 번 적용된다", "The discount is applied twice to the same order")},
				{"id": "math", "text": t("할인 단위와 0원 하한이 정책과 다르다", "Discount units and the zero lower bound violate policy")},
				{"id": "green", "text": t("할인액 대신 최종 금액을 버림한 것만 문제다", "Only rounding the final charge instead of the discount is wrong")},
			], "answer": "math",
			"lesson": t("테스트가 다루지 않은 정책도 있다. 10%는 10을 그대로 곱하는 값이 아니며, 할인 후 금액에는 0원 하한이 필요하다. 가설 기록과 실제 리뷰 코멘트는 별개다.", "Tests can miss policy. Ten percent is not a multiplier of ten, and the final amount needs a zero lower bound. A notebook hypothesis does not submit a review comment."),
		},
		"d3_07": {
			"question": t("충돌을 지우면 배송비 기능이 완성될까?", "Does removing conflict markers finish shipping?"),
			"clues": [clue("policy", t("배송비의 경계값", "Shipping boundaries"), t("50,000원부터 기본 배송비 무료, 도서산간은 추가 요금, 빈 주문은 배송비 없음. 경계와 예외를 함께 확인해야 한다.", "Base shipping is free from 50,000; remote regions add a fee; empty orders have none. Check boundaries and exceptions together."), "wiki_page", "shipping", "wiki", t("Wiki에서 배송비 정책 읽기", "Read the shipping policy in Wiki")), clue("code", t("주문 합계의 호출 경로", "The order-total path"), t("orders.ts를 읽었다. 상품 합계와 배송비를 어디서 더하는지, subtotal 리팩터링이 유지되는지 확인하자.", "You read orders.ts. Check where shipping is added and whether the subtotal refactor is preserved."), "code_viewed", "src/orders/orders.ts", "ide", t("DevIDE에서 orders.ts 열기", "Open orders.ts in DevIDE")), clue("conflict", t("실제로 확인된 병합 충돌", "A detected merge conflict"), t("이 업무의 PR이 main과 충돌한다. 두 변경의 목적을 살려 합쳐야 한다.", "This task's PR conflicts with main. Preserve the intent of both changes."), "conflict", "", "codehub", t("CodeHub에서 PR 상태 확인", "Check the PR status in CodeHub"))],
			"hypotheses": [
				{"id": "ours", "text": t("subtotal에 배송비가 이미 포함돼 중복 계산된다", "subtotal already includes shipping, causing a double charge")},
				{"id": "theirs", "text": t("리팩터링만 유지하면 배송비 정책도 반영된다", "Keeping the refactor alone also preserves the shipping policy")},
				{"id": "both", "text": t("subtotal과 배송비 정책을 함께 살려야 한다", "Preserve subtotal and the shipping policy together")},
			], "answer": "both",
			"lesson": t("충돌 표시는 증상이다. 두 변경이 지키려던 동작을 함께 검증해야 충돌 해결이 끝난다. 경계값과 도서산간도 같은 기준으로 확인한다.", "Conflict markers are a symptom. Resolution means validating the behavior intended by both changes, including boundaries and remote shipping."),
		},
		"d4_08": {
			"question": t("로그인이 끝나지 않는 이유는 무엇일까?", "Why does login never finish?"),
			"clues": [clue("logs", t("인증 서버를 기다리는 요청", "Requests waiting on the identity provider"), t("Monitor에서 인증 장애 로그를 읽었다. 응답이 없는 요청이 오래 대기하고 연결 풀이 차는 흐름이 보인다.", "You read the auth incident logs in Monitor: unanswered requests keep waiting and exhaust the connection pool."), "monitor_viewed", "auth_down", "monitor", t("Monitor에서 인증 로그 확인", "Read the auth logs in Monitor")), clue("policy", t("구분해야 할 세 가지 결과", "Three distinct outcomes"), t("타임아웃, 토큰 없음, 인증 공급자 오류는 서로 다른 결과로 전달해야 한다.", "Timeouts, missing tokens, and provider errors must remain distinct outcomes."), "wiki_page", "auth", "wiki", t("Wiki에서 인증 정책 읽기", "Read the auth policy in Wiki")), clue("code", t("인증 함수의 종료 경로", "How login finishes"), t("login.ts를 읽었다. 응답하지 않는 Promise의 종료 조건과 catch가 어떤 오류를 바꾸는지 살펴보자.", "You read login.ts. Check what ends an unanswered Promise and which errors its catch changes."), "code_viewed", "src/auth/login.ts", "ide", t("DevIDE에서 login.ts 열기", "Open login.ts in DevIDE"))],
			"hypotheses": [
				{"id": "token", "text": t("토큰이 없을 때 세션 생성을 계속 기다린다", "Session creation keeps waiting when no token is returned")},
				{"id": "timeout", "text": t("응답 없는 인증 요청을 끝내는 경계가 없다", "Unanswered auth requests have no termination boundary")},
				{"id": "ui", "text": t("이미 실패한 인증을 화면이 성공으로 표시한다", "The screen shows an already-failed authentication as successful")},
			], "answer": "timeout",
			"lesson": t("타임아웃은 무한 대기를 제한한다. 하지만 모든 오류를 타임아웃으로 바꾸면 원인이 숨는다. AI 초안도 토큰 없음과 공급자 오류를 따로 검증해야 한다.", "A timeout bounds the wait. Turning every error into a timeout hides causes, so validate missing tokens and provider errors in AI drafts too."),
		},
		"d4_09": {
			"question": t("쿠폰을 쓴 주문의 금액은 왜 음수가 됐을까?", "Why did a coupon order become negative?"),
			"clues": [coupon, failed, clue("logs", t("결제에 전달된 음수 금액", "Negative payment amounts"), t("Monitor에 할인 이후 음수 금액이 결제 계층으로 전달된 기록이 있다. 결제 직전보다 할인 계산부터 확인하자.", "Monitor shows negative amounts reaching payments after discounts. Inspect discount math before the payment layer."), "monitor_viewed", "payments", "monitor", t("Monitor에서 결제 로그 확인", "Read the payment logs in Monitor"))],
			"hypotheses": [
				{"id": "math", "text": t("할인 단위와 결제 하한을 바로잡아야 한다", "Correct the discount units and final-charge lower bound")},
				{"id": "retry", "text": t("결제 재시도가 같은 할인을 중복 적용한다", "Payment retries apply the same discount multiple times")},
				{"id": "disable", "text": t("양수 금액이 결제 계층에 전달되며 음수로 바뀐다", "A positive amount becomes negative in the payment layer")},
			], "answer": "math",
			"lesson": t("핫픽스는 결제 재시도가 아니라 금액을 만드는 정책 수정이다. 정률, 정액, 버림과 0원 하한을 함께 검증하면 처음 놓친 문제도 회복할 수 있다.", "The hotfix repairs the amount policy rather than retrying payment. Validate percentage, fixed discounts, rounding, and the zero bound to recover from the missed review."),
		},
	}


static func matches(c: Dictionary, kind: String, data: Dictionary, mission_id: String) -> bool:
	match c["source"]:
		"wiki_page":
			return kind == "wiki_page" and data.get("page", "") == c["target"]
		"code_viewed":
			return kind == "code_viewed" and data.get("path", "") == c["target"]
		"tests_failed":
			return kind == "tests" and int(data.get("failed", 0)) > 0
		"history":
			var argv: Array = data.get("argv", [])
			var output := String(data.get("out", ""))
			return kind == "command_finished" and int(data.get("code", -1)) == 0 and argv.size() >= 2 \
				and argv[0] == "git" and argv[1] in ["log", "blame", "show"] and not output.is_empty() \
				and (String(c["target"]).to_lower() in output.to_lower() or c["target"] in " ".join(argv))
		"pr_diff_viewed":
			return kind == "pr_diff_viewed" and data.get("mission", "") == c["target"] and not String(data.get("text", "")).is_empty()
		"monitor_viewed":
			return kind == "monitor_viewed" and data.get("mode", "") == c["target"]
		"conflict":
			return kind in ["ci", "mergeable"] and data.get("conflict", false) and data.get("mission", "") == mission_id
	return false
