"""Generate Chapter 3 (pre-order feature) content for both languages.

Writes content/commerce-api/{ko,en}/c03/* and hidden CI tests under content/ci/{ko,en}/c03_0N/.
Never deletes other chapters' files.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ("ko", "en")


def pick(value, lang):
    return value[0] if lang == "ko" else value[1]


# --- M02 deadline ---------------------------------------------------------------------------

DEADLINE_HEAD = (
    "// 예약 판매 마감. 판매자는 자기 현지 시각으로 마감을 적고, 서버는 UTC 밀리초로 비교한다.\n"
    "// 규칙: Wiki > 예약 판매 마감 시각",
    "// Pre-order deadline. Sellers write the deadline in their local time; the server compares UTC milliseconds.\n"
    "// Rules: Wiki > Pre-order deadlines",
)

DEADLINE_BUGGY = """{head}
export type Deadline = {{ local: string; offsetMinutes: number }}; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {{
  return Date.parse(d.local + ':00Z');
}}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {{
  return nowUtcMs <= deadlineUtc(d);
}}
"""

DEADLINE_FIXED = """{head}
export type Deadline = {{ local: string; offsetMinutes: number }}; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {{
  // Seller local wall-clock time minus the seller's offset gives the UTC instant.
  return Date.parse(d.local + ':00Z') - d.offsetMinutes * 60_000;
}}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {{
  // The deadline minute itself is already closed.
  return nowUtcMs < deadlineUtc(d);
}}
"""

DEADLINE_AI = """{head}
// {ai}
export type Deadline = {{ local: string; offsetMinutes: number }}; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {{
  return Date.parse(d.local + ':00Z') - d.offsetMinutes * 60_000;
}}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {{
  return nowUtcMs <= deadlineUtc(d);
}}
"""
AI_DEADLINE = ("AICode 초안: 판매자 시간대 변환을 고쳤습니다. 마감 정각의 경계는 검증하지 않았습니다.",
               "AICode draft: fixed the seller time-zone conversion. The exact-deadline boundary was not validated.")

DEADLINE_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ isOpen, deadlineUtc }} from '../src/preorder/deadline.ts';

const kst = {{ local: '2026-03-10T23:00', offsetMinutes: 540 }}; // 23:00 KST = 14:00 UTC
const at = (iso: string) => Date.parse(iso);

test('{t1}', () => {{
  assert.equal(deadlineUtc(kst), at('2026-03-10T14:00:00Z'));
}});

test('{t2}', () => {{
  assert.equal(isOpen(kst, at('2026-03-10T13:59:00Z')), true);
}});

test('{t3}', () => {{
  assert.equal(isOpen(kst, at('2026-03-10T14:01:00Z')), false);
}});

test('{t4}', () => {{
  const utc = {{ local: '2026-03-10T09:00', offsetMinutes: 0 }};
  assert.equal(isOpen(utc, at('2026-03-10T08:59:00Z')), true);
  assert.equal(isOpen(utc, at('2026-03-10T09:30:00Z')), false);
}});
"""
DEADLINE_T = {
    "t1": ("판매자 시각 23:00 KST는 UTC 14:00이다", "23:00 KST in seller time is 14:00 UTC"),
    "t2": ("마감 1분 전에는 주문할 수 있다", "orders are open one minute before the deadline"),
    "t3": ("마감 1분 뒤에는 주문할 수 없다", "orders are closed one minute after the deadline"),
    "t4": ("UTC 판매자도 같은 규칙이다", "a UTC seller follows the same rule"),
}

CI_DEADLINE = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ isOpen, deadlineUtc }} from '../src/preorder/deadline.ts';

const at = (iso: string) => Date.parse(iso);

test('{c1}', () => {{
  const kst = {{ local: '2026-03-10T23:00', offsetMinutes: 540 }};
  assert.equal(isOpen(kst, at('2026-03-10T14:00:00Z')), false);
}});

test('{c2}', () => {{
  const ny = {{ local: '2026-03-10T20:00', offsetMinutes: -300 }}; // 20:00 UTC-5 = 01:00 UTC next day
  assert.equal(deadlineUtc(ny), at('2026-03-11T01:00:00Z'));
  assert.equal(isOpen(ny, at('2026-03-11T00:30:00Z')), true);
}});

test('{c3}', () => {{
  const kst = {{ local: '2026-03-11T00:30', offsetMinutes: 540 }}; // 00:30 KST = 15:30 UTC the previous day
  assert.equal(deadlineUtc(kst), at('2026-03-10T15:30:00Z'));
}});

test('{c4}', () => {{
  const ist = {{ local: '2026-03-10T18:00', offsetMinutes: 330 }};
  assert.equal(isOpen(ist, at('2026-03-10T12:29:00Z')), true);
  assert.equal(isOpen(ist, at('2026-03-10T12:30:00Z')), false);
}});
"""
CI_DEADLINE_T = {
    "c1": ("[CI] 마감 정각에는 이미 닫혀 있다", "[CI] the exact deadline minute is already closed"),
    "c2": ("[CI] UTC보다 늦은 시간대(음수 오프셋)", "[CI] time zones behind UTC (negative offset)"),
    "c3": ("[CI] 현지 자정 이후 마감은 UTC로 전날이다", "[CI] a deadline after local midnight is the previous UTC day"),
    "c4": ("[CI] 30분 단위 오프셋", "[CI] half-hour offsets"),
}

DEADLINE_POLICY = ("""예약 판매 마감 시각

판매자는 마감을 자기 현지 시각으로 적는다. 예: '2026-03-10T23:00', offsetMinutes 540(KST).
서버는 UTC 밀리초로 저장하고 비교한다.

1. UTC 시각 = 현지 시각 - 오프셋(분). KST 23:00은 UTC 14:00이다.
2. 마감 시각 그 분부터 주문할 수 없다. 23:00 마감이면 22:59까지 주문 가능, 23:00 정각에는 닫힘.
3. 오프셋은 음수일 수도(UTC보다 늦은 지역), 30분 단위일 수도 있다.
4. 현지 자정 이후 마감은 UTC로 전날일 수 있다. 날짜만 보고 판단하지 않는다.

화면 표시는 판매자 현지 시각으로 한다: '3월 10일 23:00 (판매자 시간)까지'.
""", """Pre-order deadlines

Sellers write the deadline in their local time, e.g. '2026-03-10T23:00' with offsetMinutes 540 (KST).
The server stores and compares UTC milliseconds.

1. UTC instant = local time - offset (minutes). 23:00 KST is 14:00 UTC.
2. Orders close at the deadline minute itself. With a 23:00 deadline, 22:59 is open and 23:00 is closed.
3. Offsets can be negative (behind UTC) or half-hour steps.
4. A deadline after local midnight may be the previous day in UTC. Never decide by the date alone.

Display in the seller's local time: 'until Mar 10, 23:00 (seller time)'.
""")

# --- M03 cancel ----------------------------------------------------------------------------

CANCEL_HEAD = ("// 예약 주문 취소 요청. 규칙: Wiki > 예약 주문 취소와 환불",
               "// Pre-order cancel requests. Rules: Wiki > Pre-order cancellation and refunds")

CANCEL_BUGGY = """{head}
export type Order = {{ paid: boolean; stage: 'placed' | 'preparing' | 'shipped' }};
export type CancelResult = {{ state: 'cancelled' | 'refund_requested' | 'needs_review' | 'rejected'; refund: boolean }};

export function requestCancel(order: Order): CancelResult {{
  if (order.stage === 'shipped') return {{ state: 'rejected', refund: false }};
  return {{ state: 'cancelled', refund: order.paid }};
}}
"""

CANCEL_FIXED = """{head}
export type Order = {{ paid: boolean; stage: 'placed' | 'preparing' | 'shipped' }};
export type CancelResult = {{ state: 'cancelled' | 'refund_requested' | 'needs_review' | 'rejected'; refund: boolean }};

export function requestCancel(order: Order): CancelResult {{
  if (order.stage === 'shipped') return {{ state: 'rejected', refund: false }};
  // Shipping preparation started: the seller decides. Nothing is refunded automatically.
  if (order.stage === 'preparing') return {{ state: 'needs_review', refund: false }};
  if (order.paid) return {{ state: 'refund_requested', refund: true }};
  return {{ state: 'cancelled', refund: false }};
}}
"""

CANCEL_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ requestCancel }} from '../src/preorder/cancel.ts';

test('{t1}', () => {{
  assert.deepEqual(requestCancel({{ paid: false, stage: 'placed' }}), {{ state: 'cancelled', refund: false }});
}});

test('{t2}', () => {{
  assert.deepEqual(requestCancel({{ paid: true, stage: 'placed' }}), {{ state: 'refund_requested', refund: true }});
}});

test('{t3}', () => {{
  assert.deepEqual(requestCancel({{ paid: true, stage: 'preparing' }}), {{ state: 'needs_review', refund: false }});
}});

test('{t4}', () => {{
  assert.deepEqual(requestCancel({{ paid: true, stage: 'shipped' }}), {{ state: 'rejected', refund: false }});
}});
"""
CANCEL_T = {
    "t1": ("결제 전 취소는 그냥 취소다", "cancelling before payment is a plain cancel"),
    "t2": ("결제 후 취소는 환불 요청으로 따로 남는다", "cancelling after payment becomes a refund request"),
    "t3": ("배송 준비 중이면 판매자 확인이 필요하다", "orders in preparation need the seller's review"),
    "t4": ("발송된 주문은 취소할 수 없다", "shipped orders cannot be cancelled"),
}

CI_CANCEL = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ requestCancel }} from '../src/preorder/cancel.ts';

test('{c1}', () => {{
  assert.deepEqual(requestCancel({{ paid: false, stage: 'preparing' }}), {{ state: 'needs_review', refund: false }});
}});

test('{c2}', () => {{
  assert.deepEqual(requestCancel({{ paid: false, stage: 'shipped' }}), {{ state: 'rejected', refund: false }});
}});

test('{c3}', () => {{
  for (const stage of ['placed', 'preparing', 'shipped'] as const) {{
    const r = requestCancel({{ paid: true, stage }});
    assert.equal(r.refund, r.state === 'refund_requested');
  }}
}});
"""
CI_CANCEL_T = {
    "c1": ("[CI] 결제 전이라도 배송 준비 중이면 판매자 확인", "[CI] unpaid orders in preparation still need review"),
    "c2": ("[CI] 결제 전 발송 주문도 거절", "[CI] unpaid shipped orders are rejected too"),
    "c3": ("[CI] 자동 환불은 환불 요청 상태에서만", "[CI] automatic refunds only for refund requests"),
}

CANCEL_POLICY = ("""예약 주문 취소와 환불

requestCancel(order) -> { state, refund }
order: { paid, stage: 'placed' | 'preparing' | 'shipped' }

| 단계 | 결제 전 | 결제 후 |
|---|---|---|
| placed(접수) | cancelled, 환불 없음 | refund_requested, 환불 true |
| preparing(배송 준비) | needs_review | needs_review (자동 환불 없음) |
| shipped(발송) | rejected | rejected |

결제 후 취소를 '취소'로 같이 저장하면 정산에서 환불 기록이 사라진다.
배송 준비 중 처리는 Alex가 판매자와 확인한 규칙이다: 판매자가 직접 판단한다.
""", """Pre-order cancellation and refunds

requestCancel(order) -> { state, refund }
order: { paid, stage: 'placed' | 'preparing' | 'shipped' }

| Stage | Unpaid | Paid |
|---|---|---|
| placed | cancelled, no refund | refund_requested, refund true |
| preparing | needs_review | needs_review (no automatic refund) |
| shipped | rejected | rejected |

Saving a paid cancellation as plain 'cancelled' loses the refund record in settlement.
Orders in preparation follow the rule Alex agreed with sellers: the seller decides.
""")

# --- M05 labels ----------------------------------------------------------------------------

LABELS_BUGGY = ("""// 예약 상품 화면 문구. 테스트: tests/labels.test.ts
export const LABELS = {{
  shipDate: '도착 예정일',
  note: '예약 상품입니다.',
}};

export function shippingLine(dateText: string): string {{
  return `${{LABELS.shipDate}}: ${{dateText}} · ${{LABELS.note}}`;
}}
""", """// Pre-order product wording. Tests: tests/labels.test.ts
export const LABELS = {{
  shipDate: 'Arrives by',
  note: 'This is a pre-order item.',
}};

export function shippingLine(dateText: string): string {{
  return `${{LABELS.shipDate}}: ${{dateText}} · ${{LABELS.note}}`;
}}
""")

LABELS_FIXED = ("""// 예약 상품 화면 문구. 테스트: tests/labels.test.ts
export const LABELS = {{
  shipDate: '발송 예정일',
  note: '발송 후 보통 1~2일 뒤 받으실 수 있어요.',
}};

export function shippingLine(dateText: string): string {{
  return `${{LABELS.shipDate}}: ${{dateText}} · ${{LABELS.note}}`;
}}
""", """// Pre-order product wording. Tests: tests/labels.test.ts
export const LABELS = {{
  shipDate: 'Ships by',
  note: 'Delivery usually takes 1-2 days after shipping.',
}};

export function shippingLine(dateText: string): string {{
  return `${{LABELS.shipDate}}: ${{dateText}} · ${{LABELS.note}}`;
}}
""")

LABELS_TEST = ("""import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ shippingLine }} from '../src/preorder/labels.ts';

test('배송 예정일은 발송 날짜로 읽혀야 한다', () => {{
  const line = shippingLine('3월 20일');
  assert.match(line, /발송/);
  assert.doesNotMatch(line, /도착|수령/);
}});

test('받는 시점은 따로 안내한다', () => {{
  assert.match(shippingLine('3월 20일'), /받/);
}});
""", """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ shippingLine }} from '../src/preorder/labels.ts';

test('the date reads as a ship date', () => {{
  const line = shippingLine('Mar 20');
  assert.match(line, /Ships/);
  assert.doesNotMatch(line, /Arrive|Receive/i);
}});

test('delivery timing is explained separately', () => {{
  assert.match(shippingLine('Mar 20'), /[Dd]elivery/);
}});
""")

# --- Wiki pages ----------------------------------------------------------------------------

SCOPE_DOC = ("""예약 판매 v1 범위 (초안)

출시일: Alex가 신규 계약 데모에 맞춰 정함. 개발 가능 기간 6일.
요청 항목(비용, 일):
- 판매자 현지 시각 마감 (2) — 필수
- 취소와 환불 요청 분리 (2) — 필수
- 배송 예정일 표시 (1) — 필수
- 1인 구매 수량 제한 (2)
- 쿠폰과 예약 상품 결합 (3)
- 입고 알림 문자 (2)

필수 세 가지가 5일이다. 하나를 더 넣으면 기간을 넘는다.
수용 조건은 확인할 수 있는 문장으로 적는다. '대략', '쯤'은 확인할 수 없다.
""", """Pre-order v1 scope (draft)

Launch date: set by Alex for the new contract demo. Six working days available.
Requested items (cost in days):
- Deadline in seller local time (2) — required
- Separate cancel and refund requests (2) — required
- Ship-date display (1) — required
- Per-buyer quantity limit (2)
- Coupons with pre-order items (3)
- Restock SMS alerts (2)

The three required items take five days. One more item goes over the budget.
Write acceptance criteria as checkable sentences. 'Around' or 'roughly' cannot be checked.
""")

RELEASE_DOC = ("""출시와 담당

출시 공지에는 무엇이 바뀌었는지, 누구에게 적용되는지, 되돌리는 조건을 적는다.
출시 후 확인 대상은 기능이 실제로 하는 일을 보여 주는 지표로 고른다.
- 좋은 예: 마감 직후 주문 차단 로그, 취소 요청의 상태 분포, 배송 문구 관련 문의 수
- 관련 없는 예: 서버 CPU 사용률(예약 판매와 무관하게 변한다)

기능이 끝나도 담당은 남는다. 담당자, 문의 받는 시간, 공용 채널, 운영 설명서를 정한다.
개인 메시지로 문의를 받으면 그 사람이 쉬는 날 기능도 쉰다.
""", """Release and ownership

A release note says what changed, who it applies to, and when we roll back.
Pick post-release checks that show what the feature actually does.
- Good: order-blocking logs right after deadlines, cancel-request state mix, ship-date wording inquiries
- Unrelated: server CPU (moves for reasons unrelated to pre-orders)

When a feature ships, ownership remains: an owner, inquiry hours, a shared channel, and a runbook.
If questions arrive by DM, the feature takes a day off whenever that person does.
""")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def fill(template: str, names: dict, lang: str, **extra) -> str:
    # Test titles sit inside single-quoted TypeScript strings.
    values = {k: pick(v, lang).replace("\\", "\\\\").replace("'", "\\'") for k, v in names.items()}
    values.update(extra)
    return template.format(**values)


def main() -> None:
    count = 0
    for lang in LANGS:
        base = ROOT / "content" / "commerce-api" / lang / "c03"
        ci = ROOT / "content" / "ci" / lang
        head = pick(DEADLINE_HEAD, lang)
        chead = pick(CANCEL_HEAD, lang)
        files = {
            base / "deadline.ts": DEADLINE_BUGGY.format(head=head),
            base / "deadline_fixed.ts": DEADLINE_FIXED.format(head=head),
            base / "deadline_ai.ts": DEADLINE_AI.format(head=head, ai=pick(AI_DEADLINE, lang)),
            base / "deadline.test.ts": fill(DEADLINE_TEST, DEADLINE_T, lang),
            ci / "c03_02" / "ci_deadline.test.ts": fill(CI_DEADLINE, CI_DEADLINE_T, lang),
            base / "deadline_policy.txt": pick(DEADLINE_POLICY, lang),
            base / "cancel.ts": CANCEL_BUGGY.format(head=chead),
            base / "cancel_fixed.ts": CANCEL_FIXED.format(head=chead),
            base / "cancel.test.ts": fill(CANCEL_TEST, CANCEL_T, lang),
            ci / "c03_03" / "ci_cancel.test.ts": fill(CI_CANCEL, CI_CANCEL_T, lang),
            base / "cancel_policy.txt": pick(CANCEL_POLICY, lang),
            base / "labels.ts": pick(LABELS_BUGGY, lang).format(),
            base / "labels_fixed.ts": pick(LABELS_FIXED, lang).format(),
            base / "labels.test.ts": pick(LABELS_TEST, lang).format(),
            base / "scope.txt": pick(SCOPE_DOC, lang),
            base / "release_policy.txt": pick(RELEASE_DOC, lang),
        }
        for path, text in files.items():
            write(path, text)
            count += 1
    print(f"{count} chapter-three files written")


if __name__ == "__main__":
    main()
