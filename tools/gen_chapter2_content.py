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


def files(lang):
    index = 0 if lang == "ko" else 1
    result = {}
    for name in ("request.ts", "request_sequential.ts", "request_store.ts", "request.test.ts", "request_probe.mjs", "ci_requests.test.ts"):
        value = (TEMPLATE / name).read_text(encoding="utf-8")
        for key, pair in TEXT.items():
            value = value.replace("{{" + key + "}}", pair[index])
        top = "ci" if name.startswith("ci_") else "commerce-api"
        result[f"{top}/c02/{name}"] = value
    result["commerce-api/c02/policy.txt"] = POLICY_KO if lang == "ko" else POLICY_EN
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
