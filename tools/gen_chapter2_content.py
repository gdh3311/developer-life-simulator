"""Generate the chapter-two slice without deleting existing chapter-one content."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools" / "templates" / "chapter02"

TEXT = {
    "INTRO": ("달빛상점의 주문 요청 처리. 정책: Wiki > 주문 요청과 재시도", "Moonlight order requests. Contract: Wiki > Order requests and retries"),
    "SCOPE": ("TODO: 순차 재시도 계약을 구현하세요. 동시 요청은 다음 업무에서 다룹니다.", "TODO: implement the sequential retry contract. Concurrent requests are a later task."),
    "SEQUENTIAL": ("AICode 초안: 순차 요청만 검증했습니다. 동시성은 해결하지 않았습니다.", "AICode draft: validated for sequential calls only; concurrency is not solved."),
    "T_NORMAL": ("새 요청은 주문 하나를 생성한다", "a new request creates one order"),
    "T_RETRY": ("같은 요청을 재전송해도 같은 주문이다", "retrying the same request returns the same order"),
    "T_CONFLICT": ("같은 키에 다른 내용은 충돌이다", "different contents with the same key conflict"),
    "T_SHOPS": ("상점이 다르면 같은 키도 별개다", "different shops may use the same request key"),
    "T_EMPTY": ("비어 있는 요청 키는 주문을 만들지 않는다", "empty request keys do not create orders"),
    "CI_SCOPE": ("공개 정책의 순차 호출만 검증한다. 동시성은 아직 요구하지 않는다.", "Checks the published sequential contract; concurrency is not required yet."),
    "C_REPEAT": ("[CI] 복사된 요청을 반복해도 주문 하나", "[CI] repeated cloned requests create only one order"),
    "C_BOUNDARY": ("[CI] 상점 ID와 요청 키는 독립적인 쌍이다", "[CI] shop ID and request key form an independent pair"),
    "C_CONFLICT": ("[CI] 수량 변경도 다른 주문 내용이다", "[CI] a quantity change is different request content"),
    "C_KEY": ("[CI] 키 공백 정규화와 빈 키 검증", "[CI] normalize key whitespace and reject empty keys"),
}

POLICY_KO = """주문 요청과 순차 재시도

createOrder(request, store) -> Promise<Order>
request: { shopId, requestKey, items }
items는 순서가 정규화된 { sku, price, quantity } 목록이다.

1. requestKey의 앞뒤 공백을 제거한다. null, 누락, 공백뿐인 키는 REQUEST_KEY_REQUIRED 오류이며 주문을 만들지 않는다.
2. 같은 shopId와 정규화한 requestKey의 쌍에 같은 items가 오면 처음 만든 주문을 반환한다.
3. 같은 쌍인데 items가 다르면 REQUEST_CONFLICT 오류다. 수량과 가격도 내용에 포함한다.
4. shopId나 requestKey 중 하나라도 다르면 별개의 요청이다. 문자열에 ':' 같은 문자가 있어도 쌍의 경계는 유지한다.
5. 이번 업무는 순차 호출만 다룬다. 동시 요청, 만료, 실제 DB 배포는 다음 업무의 범위다.

store.get(key): 저장한 Entry 또는 undefined
store.set(key, { fingerprint, order }): 완료한 주문과 내용 지문 저장
store.create(request): 새 주문을 만드는 Promise
key와 fingerprint를 만드는 방식은 자유다. 쌍의 구분과 내용 비교가 지켜져야 한다.
예: key = JSON.stringify([request.shopId, requestKey]); fingerprint = JSON.stringify(request.items)

실험실은 요청 조건을 가상으로 조합하고 실제 request.ts 함수를 순차 실행한다.
느린 응답 + 재시도 켜기 + 같은 키: 호출은 2번이지만 수정 후 주문은 1개여야 한다.
느린 응답 + 재시도 끄기: 호출은 1번이다.
매번 새 키는 서로 다른 구매 시도이므로 주문이 여러 개 생겨도 정상이다.

Lab에서 신고된 버전과 현재 작업 코드의 차이를 비교할 수 있다.
실험 성공은 배포 완료를 뜻하지 않는다. 실제 동시성·고객 적용 확인은 남아 있다.
"""
POLICY_EN = """Order requests and sequential retries

createOrder(request, store) -> Promise<Order>
request: { shopId, requestKey, items }
items is an ordered, normalized list of { sku, price, quantity }.

1. Trim requestKey. Null, missing, or whitespace-only keys throw REQUEST_KEY_REQUIRED without creating an order.
2. The same shopId and normalized requestKey pair with the same items returns the first order.
3. The same pair with different items throws REQUEST_CONFLICT. Price and quantity are part of the content.
4. Changing either shopId or requestKey makes a separate request. Preserve pair boundaries even when strings contain ':'.
5. This task covers sequential calls only. Concurrent requests, expiry, and actual database deployment come later.

store.get(key): saved Entry or undefined
store.set(key, { fingerprint, order }): save the completed order and content fingerprint
store.create(request): a Promise creating a new order
Choose your implementation freely, while preserving pair boundaries and content equality.
Example: key = JSON.stringify([request.shopId, requestKey]); fingerprint = JSON.stringify(request.items)

Lab simulates response conditions and runs the actual request.ts function sequentially.
Slow response + retries on + same key: two calls should create one order after the fix.
Slow response + retries off: one call.
New keys represent separate purchase attempts, so multiple orders are expected.

Compare the reported version with current working code in Lab.
A successful experiment is not a production rollout. Concurrency and customer verification are still pending.
"""

TEXT.update({
    # M04 logs
    "LOG_INTRO": ("디버그 로그: 재현하느라 요청 전체를 그대로 출력했다. 정책: Wiki > 로그에 남길 것", "Debug log: dumped the whole request while reproducing. Policy: Wiki > What logs keep"),
    "LOG_TODO": ("TODO(NXR-024): 추적에 필요한 필드만 남기세요. 구매자·결제 정보는 남기지 않습니다.", "TODO(NXR-024): keep only the fields needed for tracing. No buyer or payment data."),
    "LOG_ALLOW": ("허용 목록: 새 필드가 생겨도 자동으로 새어 나가지 않는다.", "Allowlist: new fields never leak by default."),
    "TL_TRACE": ("요청·상점·결과·처리 시간으로 추적할 수 있다", "keeps request, shop, result and duration for tracing"),
    "TL_RETRY": ("재시도 여부를 구분할 수 있다", "distinguishes retries"),
    "TL_PRIVATE": ("구매자 정보와 결제 토큰은 남기지 않는다", "never keeps buyer details or the payment token"),
    "CL_SCOPE": ("공개 정책의 원칙을 새 입력에 적용한다: 허용한 필드만 남긴다.", "Applies the published principle to new inputs: keep only allowed fields."),
    "CL_NEW_FIELDS": ("[CI] 나중에 추가된 민감 필드도 새지 않는다", "[CI] sensitive fields added later never leak"),
    "CL_FAILURE": ("[CI] 실패 결과도 추적 정보가 남는다", "[CI] failures keep tracing information too"),
    "CL_ATTEMPTS": ("[CI] 첫 시도와 세 번째 시도를 구분한다", "[CI] the first and third attempts differ"),
    # M05 screen states
    "ST_INTRO": ("주문 응답을 화면 상태로 바꾼다. 합의: Wiki > 주문 화면 상태", "Maps order responses to screen states. Agreement: Wiki > Order screen states"),
    "ST_UNKNOWN": ("응답을 못 받았다고 실패는 아니다. 같은 키로 결과를 확인하거나 재시도한다.", "No response is not a failure. Check or retry with the same key."),
    "TS_CONFIRMED": ("생성된 주문은 주문 번호와 함께 확정으로 보여 준다", "a created order is confirmed with its number"),
    "TS_EXISTING": ("이미 있던 주문도 같은 번호로 확정이다", "an existing order is confirmed with the same number"),
    "TS_CONFLICT": ("내용 충돌은 재확인 안내와 새 키", "a content conflict asks for review with a new key"),
    "TS_UNKNOWN": ("결과를 모르면 실패가 아니라 확인 중이고 같은 키를 유지한다", "an unknown result is checking, not failure, and keeps the key"),
    # M06 concurrency
    "STORE_DOC": ("테스트용 저장소. claim은 원자적이다: 같은 키를 동시에 선점할 수 있는 요청은 하나뿐이다.", "Test store. claim is atomic: only one request can claim a key at a time."),
    "TC_PARALLEL": ("동시에 두 번 보내도 주문은 하나다", "two simultaneous requests create one order"),
    "TC_RECOVER": ("생성이 실패해도 선점이 남지 않아 재시도할 수 있다", "a failed creation releases the claim so a retry works"),
    "TC_SEQUENTIAL": ("순차 재시도 계약은 그대로 유지된다", "the sequential retry contract still holds"),
    "CC_SCOPE": ("공개된 동시성 계약의 입력을 넓혀 확인한다.", "Widens the inputs of the published concurrency contract."),
    "CC_FIVE": ("[CI] 다섯 번 동시에 보내도 주문 하나", "[CI] five simultaneous requests create one order"),
    "CC_SHOPS": ("[CI] 다른 상점의 같은 키는 동시에 와도 별개", "[CI] the same key from different shops stays separate"),
    "CC_PENDING_CONFLICT": ("[CI] 생성 중인 같은 키에 다른 내용이 오면 충돌", "[CI] different contents while the key is being created conflict"),
    "CC_FAIL_WAITER": ("[CI] 기다리던 요청이 있어도 실패 후 재시도는 한 번만 생성", "[CI] after a failure with a waiter, a retry creates exactly once"),
    "CC_EMPTY": ("[CI] 빈 키는 동시에 와도 주문을 만들지 않는다", "[CI] empty keys never create orders, even concurrently"),
    "AI_CONCURRENT": ("AICode 초안: claim/complete/release로 동시 요청과 실패 복구를 처리했습니다. 생성 중(pending)일 때의 내용 비교는 검증하지 않았습니다.", "AICode draft: handles concurrent calls and failure recovery with claim/complete/release. Content comparison while a claim is pending was not validated."),
})

LOG_POLICY = (
"""로그에 남길 것 (NXR-024)

재현할 때는 요청 전체를 출력했지만, 운영 로그에는 추적에 필요한 것만 남긴다.

남긴다: 요청 ID, 상점 ID, 결과 코드, 시도 횟수 또는 재시도 여부, 처리 시간
남기지 않는다: 구매자 이름·주소·연락처, 결제 토큰, 카드 정보, 메모 같은 자유 입력

원칙: '지울 필드'를 고르는 거부 목록이 아니라 '남길 필드'를 고르는 허용 목록으로 만든다.
그래야 나중에 이벤트에 새 필드가 추가돼도 자동으로 로그에 새지 않는다.

필드 이름은 자유다. 추적 정보가 남고, 제외 대상이 어떤 형태로도 남지 않으면 된다.
고객 정보가 필요하면 권한이 있는 사람이 지원 도구에서 주문 번호로 조회한다.
""",
"""What logs keep (NXR-024)

We printed the whole request while reproducing, but production logs keep only what tracing needs.

Keep: request ID, shop ID, result code, attempt count or a retry flag, duration
Never keep: buyer name, address and phone, payment token, card data, free-text notes

Principle: build an allowlist of fields to keep, not a denylist of fields to remove.
That way a field added to the event later never leaks into logs by default.

Field names are up to you. Tracing data must remain and excluded data must not appear in any form.
When customer details are needed, authorized staff look them up by order number in the support tool.
""")

STATES_POLICY = (
"""주문 화면 상태 (NXR-025 · Sophie와 합의)

| 상태 | 화면 | 서버와의 약속 |
| 요청 전 | 주문 버튼 사용 가능 | 새 요청 키 준비 |
| 응답 대기 | 처리 중 표시 | 같은 시도에는 같은 키 유지 |
| 결과를 아직 모름 (timeout) | 확인 중 표시 + 확인 동작 | 같은 키로 결과 확인 또는 재시도 |
| 주문 확정 (created / existing) | 기존 주문 번호 표시 | 같은 키에 같은 결과 |
| 내용 충돌 (conflict) | 주문 내용 재확인 안내 | 새 시도에서 새 키 사용 |
| 처리 전 실패 (error) | 실패 안내 | 새 시도 가능 |

핵심: 응답을 받지 못한 것은 실패가 아니다. 실패라고 보여 주면 고객은 다시 누르고,
새 키로 다시 보내면 서버의 중복 방지가 작동하지 못한다.
상태 이름은 자유다. 거짓 실패를 보여 주지 않고, 모르는 동안 같은 키를 유지하면 된다.
""",
"""Order screen states (NXR-025 · agreed with Sophie)

| State | Screen | Promise with the server |
| Before request | Order button enabled | Prepare a new request key |
| Waiting | Processing indicator | Keep the same key for this attempt |
| Result unknown (timeout) | "Checking" + a check action | Check or retry with the same key |
| Confirmed (created / existing) | Show the existing order number | Same key returns the same result |
| Content conflict | Ask to review the order | New attempt uses a new key |
| Failed before processing (error) | Failure message | A new attempt is allowed |

Key point: not receiving a response is not a failure. Showing "failed" makes customers click again,
and resending with a new key defeats the server's duplicate protection.
State names are up to you. Never show a false failure, and keep the key while the result is unknown.
""")

CONCURRENCY_POLICY = (
"""동시 요청과 선점 (NXR-026)

순차 요청에서는 '있는지 확인(get) → 만들기(create) → 저장(set)'으로 충분했다.
두 요청이 동시에 오면 둘 다 확인 단계에서 '없음'을 보고 각자 주문을 만든다.

저장소의 선점 계약 (tests/request_store.ts):
  store.claim(key, fingerprint) — 한 번에 판정한다(원자적).
    { status: 'new' }                          → 내가 선점했다. 주문을 만들어야 한다.
    { status: 'pending', fingerprint, wait }   → 다른 요청이 만드는 중. wait(Promise)을 기다린다.
    { status: 'done', fingerprint, order }     → 이미 완료된 주문.
  store.complete(key, order) — 완료를 기록하고 기다리던 요청에 결과를 전달한다.
  store.release(key, error) — 생성 실패 시 선점을 풀어 다음 재시도가 가능하게 한다.

규칙:
1. 순차 계약(빈 키, 상점·키 쌍, 내용 충돌)은 그대로다.
2. pending이나 done인데 fingerprint가 다르면 REQUEST_CONFLICT다.
3. 생성이 실패하면 반드시 release한다. 실패가 고정되면 고객은 영원히 주문할 수 없다.

비유: 택배 접수증. 접수증(선점)을 먼저 받은 사람만 물건을 보내고,
같은 접수 번호로 온 사람은 이미 보낸 택배의 송장(결과)을 받는다.
""",
"""Concurrent requests and claims (NXR-026)

For sequential calls, "check (get) → create → save (set)" was enough.
When two requests arrive at once, both see "nothing yet" and each creates an order.

The store's claim contract (tests/request_store.ts):
  store.claim(key, fingerprint) — decides in one step (atomic).
    { status: 'new' }                          → you hold the claim; create the order.
    { status: 'pending', fingerprint, wait }   → someone else is creating it; await wait (a Promise).
    { status: 'done', fingerprint, order }     → an order already exists.
  store.complete(key, order) — records completion and hands the result to waiting requests.
  store.release(key, error) — on failure, frees the claim so a later retry can succeed.

Rules:
1. The sequential contract (empty key, shop/key pair, content conflict) still holds.
2. A pending or done claim with a different fingerprint is REQUEST_CONFLICT.
3. Always release when creation fails. A stuck failure means the customer can never order.

Analogy: a parcel receipt. Only the person holding the receipt (claim) ships the parcel;
anyone arriving with the same receipt number gets the tracking number (result) of that parcel.
""")

ROLLOUT_POLICY = (
"""배포와 관찰 기준 (NXR-027)

'병합했다'와 '고객 문제가 해결됐다'는 다른 시점이다.

1. 제한 적용: 문제를 신고한 상점(달빛상점)에 먼저 적용한다.
2. 관찰: 오류율, 요청 수, 재시도 결과, 고객 문의를 함께 본다.
3. 근거: '중복 0건'만으로는 부족하다. 주문과 재시도가 실제로 있었는데도 중복이 없어야 한다.
4. 기록: 현재 확인 범위, 다음 확인 시점, 담당자를 남긴다.
5. 되돌리기는 실패가 아니다. 기준에 못 미치면 제한을 유지하거나 되돌리고 다시 확인한다.
""",
"""Rollout and observation (NXR-027)

"Merged" and "the customer's problem is solved" happen at different times.

1. Limited rollout: apply to the reporting shop (Moonlight) first.
2. Observe: error rate, request volume, retry results and customer inquiries together.
3. Evidence: "zero duplicates" alone is not enough. Orders and retries must actually have happened without duplicates.
4. Record: the current scope, the next check time and the owner.
5. Rolling back is not failure. If the bar isn't met, keep the limit or roll back, then check again.
""")


# template -> output path (relative to content/<top>/<lang>/)
OUTPUTS = {
    "request.ts": "commerce-api/c02/request.ts",
    "request_sequential.ts": "commerce-api/c02/request_sequential.ts",
    "request_store.ts": "commerce-api/c02/request_store.ts",
    "request.test.ts": "commerce-api/c02/request.test.ts",
    "request_probe.mjs": "commerce-api/c02/request_probe.mjs",
    "ci_requests.test.ts": "ci/c02/ci_requests.test.ts",
    "request_log.ts": "commerce-api/c02/request_log.ts",
    "request_log_fixed.ts": "commerce-api/c02/request_log_fixed.ts",
    "request_log.test.ts": "commerce-api/c02/request_log.test.ts",
    "ci_request_log.test.ts": "ci/c02_04/ci_request_log.test.ts",
    "order_status.ts": "commerce-api/c02/order_status.ts",
    "order_status_fixed.ts": "commerce-api/c02/order_status_fixed.ts",
    "order_status.test.ts": "commerce-api/c02/order_status.test.ts",
    "order_status_fixed.test.ts": "commerce-api/c02/order_status_fixed.test.ts",
    "request_store_v2.ts": "commerce-api/c02/request_store_v2.ts",
    "requests_concurrent.test.ts": "commerce-api/c02/requests_concurrent.test.ts",
    "ci_requests_concurrent.test.ts": "ci/c02_06/ci_requests_concurrent.test.ts",
    "request_concurrent.ts": "commerce-api/c02/request_concurrent.ts",
    "request_concurrent_ai.ts": "commerce-api/c02/request_concurrent_ai.ts",
}


def files(lang):
    index = 0 if lang == "ko" else 1
    result = {}
    for name, target in OUTPUTS.items():
        value = (TEMPLATE / name).read_text(encoding="utf-8")
        for key, pair in TEXT.items():
            value = value.replace("{{" + key + "}}", pair[index])
        result[target] = value
    result["commerce-api/c02/policy.txt"] = POLICY_KO if lang == "ko" else POLICY_EN
    result["commerce-api/c02/log_policy.txt"] = LOG_POLICY[index]
    result["commerce-api/c02/states_policy.txt"] = STATES_POLICY[index]
    result["commerce-api/c02/concurrency_policy.txt"] = CONCURRENCY_POLICY[index]
    result["commerce-api/c02/rollout_policy.txt"] = ROLLOUT_POLICY[index]
    return result


def main():
    count = 0
    for lang in ("ko", "en"):
        for relative, value in files(lang).items():
            top, rest = relative.split("/", 1)
            target = ROOT / "content" / top / lang / rest
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(value, encoding="utf-8", newline="\n")
            count += 1
    print(f"{count} chapter-two files written")


if __name__ == "__main__":
    main()
