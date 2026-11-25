"""Generate Chapter 5 (the day everyone shows up) content for both languages.

Writes content/commerce-api/{ko,en}/c05/* and hidden CI under content/ci/{ko,en}/c05_0{2,3,4}/.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ("ko", "en")


def pick(v, lang):
    return v[0] if lang == "ko" else v[1]


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def fill(t, names, lang, **extra):
    values = {k: esc(pick(v, lang)) for k, v in names.items()}
    values.update(extra)
    return t.format(**values)


# --- M02 inventory reservation ---------------------------------------------------------------

RESERVE_HEAD = ("""// 캠페인 재고 예약. 정책: Wiki > 캠페인 준비 > 재고 예약
// reserve: 결제 전 10분간 한 개를 잡아 둔다 · confirm: 결제 성공 시 판매 확정 · cancel: 예약 해제""",
                """// Campaign inventory holds. Policy: Wiki > Campaign prep > Inventory holds
// reserve: hold one item for 10 minutes before payment · confirm: sell on payment success · cancel: release""")

RESERVE_BUGGY = """{head}
export type Clock = {{ now(): number }};
export type Audit = (event: string, orderId: string) => Promise<void>;

export class Inventory {{
  private holds = new Map<string, number>(); // orderId -> expiresAt
  private sold = 0;

  private stock: number;
  private clock: Clock;
  private audit: Audit;
  private holdMs: number;

  constructor(stock: number, clock: Clock, audit: Audit = async () => {{}}, holdMs = 600_000) {{
    this.stock = stock;
    this.clock = clock;
    this.audit = audit;
    this.holdMs = holdMs;
  }}

  available(): number {{
    return this.stock - this.sold - this.holds.size;
  }}

  async reserve(orderId: string): Promise<boolean> {{
    if (this.holds.has(orderId)) return true;
    if (this.available() <= 0) return false;
    await this.audit('reserve', orderId);
    this.holds.set(orderId, this.clock.now() + this.holdMs);
    return true;
  }}

  confirm(orderId: string): boolean {{
    if (!this.holds.has(orderId)) return false;
    this.holds.delete(orderId);
    this.sold += 1;
    return true;
  }}

  cancel(orderId: string): boolean {{
    return this.holds.delete(orderId);
  }}
}}
"""

RESERVE_FIXED = """{head}
export type Clock = {{ now(): number }};
export type Audit = (event: string, orderId: string) => Promise<void>;

export class Inventory {{
  private holds = new Map<string, number>(); // orderId -> expiresAt
  private sold = 0;

  private stock: number;
  private clock: Clock;
  private audit: Audit;
  private holdMs: number;

  constructor(stock: number, clock: Clock, audit: Audit = async () => {{}}, holdMs = 600_000) {{
    this.stock = stock;
    this.clock = clock;
    this.audit = audit;
    this.holdMs = holdMs;
  }}

  // Expired holds go back to stock before anyone looks at the count.
  private expire(): void {{
    const now = this.clock.now();
    for (const [id, expiresAt] of this.holds) {{
      if (expiresAt <= now) this.holds.delete(id);
    }}
  }}

  available(): number {{
    this.expire();
    return this.stock - this.sold - this.holds.size;
  }}

  async reserve(orderId: string): Promise<boolean> {{
    this.expire();
    if (this.holds.has(orderId)) return true;
    if (this.available() <= 0) return false;
    // Claim before any await, so concurrent requests can't all see the last item.
    this.holds.set(orderId, this.clock.now() + this.holdMs);
    try {{
      await this.audit('reserve', orderId);
    }} catch {{
      this.holds.delete(orderId);
      return false;
    }}
    return true;
  }}

  confirm(orderId: string): boolean {{
    this.expire();
    if (!this.holds.has(orderId)) return false;
    this.holds.delete(orderId);
    this.sold += 1;
    return true;
  }}

  cancel(orderId: string): boolean {{
    return this.holds.delete(orderId);
  }}
}}
"""

RESERVE_AI = """{head}
// {ai}
export type Clock = {{ now(): number }};
export type Audit = (event: string, orderId: string) => Promise<void>;

export class Inventory {{
  private holds = new Map<string, number>(); // orderId -> expiresAt
  private sold = 0;

  private stock: number;
  private clock: Clock;
  private audit: Audit;
  private holdMs: number;

  constructor(stock: number, clock: Clock, audit: Audit = async () => {{}}, holdMs = 600_000) {{
    this.stock = stock;
    this.clock = clock;
    this.audit = audit;
    this.holdMs = holdMs;
  }}

  available(): number {{
    return this.stock - this.sold - this.holds.size;
  }}

  async reserve(orderId: string): Promise<boolean> {{
    if (this.holds.has(orderId)) return true;
    if (this.available() <= 0) return false;
    this.holds.set(orderId, this.clock.now() + this.holdMs);
    await this.audit('reserve', orderId);
    return true;
  }}

  confirm(orderId: string): boolean {{
    if (!this.holds.has(orderId)) return false;
    this.holds.delete(orderId);
    this.sold += 1;
    return true;
  }}

  cancel(orderId: string): boolean {{
    return this.holds.delete(orderId);
  }}
}}
"""
RESERVE_AI_NOTE = ("AICode 초안: 동시 예약은 await 전에 선점하도록 바꿨습니다. 예약 만료와 감사 로그 실패는 검증하지 않았습니다.",
                   "AICode draft: concurrent holds now claim before the await. Hold expiry and audit-log failures were not validated.")

RESERVE_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ Inventory }} from '../src/inventory/reserve.ts';

const clock = () => {{ let t = 0; return {{ now: () => t, advance: (ms: number) => {{ t += ms; }} }}; }};

test('{t1}', async () => {{
  const inv = new Inventory(2, clock());
  assert.equal(await inv.reserve('o-1'), true);
  assert.equal(inv.confirm('o-1'), true);
  assert.equal(inv.available(), 1);
}});

test('{t2}', async () => {{
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(inv.cancel('o-1'), true);
  assert.equal(inv.available(), 1);
}});

test('{t3}', async () => {{
  const inv = new Inventory(1, clock());
  const results = await Promise.all(['o-1', 'o-2', 'o-3'].map(id => inv.reserve(id)));
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal(inv.available(), 0);
}});

test('{t4}', async () => {{
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(await inv.reserve('o-2'), false);
}});
"""
RESERVE_T = {
    "t1": ("예약 후 확정하면 재고가 하나 줄어든다", "reserving then confirming sells one item"),
    "t2": ("취소하면 예약이 풀린다", "cancelling releases the hold"),
    "t3": ("마지막 한 개에 동시 예약 세 건이 오면 하나만 성공한다", "three concurrent holds on the last item: only one succeeds"),
    "t4": ("품절이면 예약이 실패한다", "holds fail when sold out"),
}

CI_RESERVE = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ Inventory }} from '../src/inventory/reserve.ts';

const clock = () => {{ let t = 0; return {{ now: () => t, advance: (ms: number) => {{ t += ms; }} }}; }};

test('{c1}', async () => {{
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.available(), 1);
  assert.equal(await inv.reserve('o-2'), true);
}});

test('{c2}', async () => {{
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.confirm('o-1'), false);
}});

test('{c3}', async () => {{
  const inv = new Inventory(1, clock(), async () => {{ throw new Error('audit down'); }});
  assert.equal(await inv.reserve('o-1'), false);
  assert.equal(inv.available(), 1);
}});
"""
CI_RESERVE_T = {
    "c1": ("[CI] 만료된 예약은 재고로 돌아간다", "[CI] expired holds return to stock"),
    "c2": ("[CI] 만료된 예약은 확정할 수 없다", "[CI] an expired hold cannot be confirmed"),
    "c3": ("[CI] 감사 로그가 실패하면 선점을 풀고 false", "[CI] if the audit log fails, release the claim and return false"),
}

# --- M03 price cache ---------------------------------------------------------------------------

PRICE_HEAD = ("""// 상품 가격 캐시. 정책: Wiki > 캠페인 준비 > 가격 캐시
// display: 목록·상세 화면용(캐시) · checkoutPrice: 결제 금액(항상 원본) · update: 가격 변경""",
              """// Product price cache. Policy: Wiki > Campaign prep > Price cache
// display: listing/detail pages (cached) · checkoutPrice: the amount charged (always the source) · update: price change""")

PRICE_BUGGY = """{head}
export type Clock = {{ now(): number }};
export type PriceSource = {{ get(id: string): Promise<number>; set(id: string, price: number): Promise<void> }};

export class PriceCache {{
  private cache = new Map<string, {{ price: number; at: number }}>();

  private source: PriceSource;
  private clock: Clock;
  private ttlMs: number;

  constructor(source: PriceSource, clock: Clock, ttlMs = 60_000) {{
    this.source = source;
    this.clock = clock;
    this.ttlMs = ttlMs;
  }}

  async display(id: string): Promise<number> {{
    const hit = this.cache.get(id);
    if (hit && this.clock.now() - hit.at < this.ttlMs) return hit.price;
    const price = await this.source.get(id);
    this.cache.set(id, {{ price, at: this.clock.now() }});
    return price;
  }}

  async update(id: string, price: number): Promise<void> {{
    await this.source.set(id, price);
  }}

  async checkoutPrice(id: string): Promise<number> {{
    return this.display(id);
  }}
}}
"""

PRICE_FIXED = """{head}
export type Clock = {{ now(): number }};
export type PriceSource = {{ get(id: string): Promise<number>; set(id: string, price: number): Promise<void> }};

export class PriceCache {{
  private cache = new Map<string, {{ price: number; at: number }}>();

  private source: PriceSource;
  private clock: Clock;
  private ttlMs: number;

  constructor(source: PriceSource, clock: Clock, ttlMs = 60_000) {{
    this.source = source;
    this.clock = clock;
    this.ttlMs = ttlMs;
  }}

  async display(id: string): Promise<number> {{
    const hit = this.cache.get(id);
    if (hit && this.clock.now() - hit.at < this.ttlMs) return hit.price;
    const price = await this.source.get(id);
    this.cache.set(id, {{ price, at: this.clock.now() }});
    return price;
  }}

  async update(id: string, price: number): Promise<void> {{
    await this.source.set(id, price);
    this.cache.delete(id); // only this product: the rest of the cache stays warm
  }}

  // Speed is for browsing; the amount we charge is read from the source every time.
  async checkoutPrice(id: string): Promise<number> {{
    return this.source.get(id);
  }}
}}
"""

PRICE_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ PriceCache }} from '../src/pricing/price_cache.ts';

const source = (prices: Record<string, number>) => {{
  const s = {{ reads: 0, async get(id: string) {{ s.reads += 1; return prices[id]; }}, async set(id: string, p: number) {{ prices[id] = p; }}, prices }};
  return s;
}};
const clock = () => {{ let t = 0; return {{ now: () => t, advance: (ms: number) => {{ t += ms; }} }}; }};

test('{t1}', async () => {{
  const src = source({{ tea: 12900 }});
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  await cache.display('tea');
  assert.equal(src.reads, 1);
}});

test('{t2}', async () => {{
  const cache = new PriceCache(source({{ tea: 12900 }}), clock());
  await cache.display('tea');
  await cache.update('tea', 11900);
  assert.equal(await cache.display('tea'), 11900);
}});

test('{t3}', async () => {{
  const src = source({{ tea: 12900 }});
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  src.prices.tea = 11900; // changed from the admin server, not through this cache
  assert.equal(await cache.checkoutPrice('tea'), 11900);
}});
"""
PRICE_T = {
    "t1": ("화면 가격은 캐시에서 읽는다", "display prices come from the cache"),
    "t2": ("가격을 바꾸면 바로 새 가격이 보인다", "a price change shows up immediately"),
    "t3": ("결제 금액은 캐시가 아니라 원본 가격이다", "the charged amount is the source price, not the cache"),
}

CI_PRICE = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ PriceCache }} from '../src/pricing/price_cache.ts';

const source = (prices: Record<string, number>) => {{
  const s = {{ reads: 0, async get(id: string) {{ s.reads += 1; return prices[id]; }}, async set(id: string, p: number) {{ prices[id] = p; }}, prices }};
  return s;
}};
const clock = () => {{ let t = 0; return {{ now: () => t, advance: (ms: number) => {{ t += ms; }} }}; }};

test('{c1}', async () => {{
  const src = source({{ tea: 12900 }});
  const c = clock();
  const cache = new PriceCache(src, c);
  await cache.display('tea');
  src.prices.tea = 11900;
  c.advance(61_000);
  assert.equal(await cache.display('tea'), 11900);
}});

test('{c2}', async () => {{
  const src = source({{ tea: 12900, cup: 5000 }});
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  await cache.display('cup');
  await cache.update('tea', 11900);
  const before = src.reads;
  await cache.display('cup');
  assert.equal(src.reads, before);
}});
"""
CI_PRICE_T = {
    "c1": ("[CI] 만료 시간이 지나면 원본을 다시 읽는다", "[CI] after the TTL the source is read again"),
    "c2": ("[CI] 한 상품의 가격 변경이 다른 상품 캐시를 비우지 않는다", "[CI] changing one price doesn't flush other products"),
}

# --- M04 payment webhooks ------------------------------------------------------------------------

HOOK_HEAD = ("""// 결제 웹훅 처리. 정책: Wiki > 캠페인 준비 > 결제 웹훅
// 같은 이벤트는 한 번만, 늦게 온 성공은 사람이 확인할 조정 목록으로.""",
             """// Payment webhook handling. Policy: Wiki > Campaign prep > Payment webhooks
// Each event once; late successes go to the reconciliation list for a person to check.""")

HOOK_TYPES = """export type PaymentEvent = {{ id: string; orderId: string; type: 'succeeded' | 'failed' }};
export type Order = {{ id: string; status: 'pending' | 'paid' | 'cancelled' | 'failed' }};
export type Ledger = {{
  orders: Map<string, Order>;
  processed: Set<string>;
  reconcile: {{ orderId: string; eventId: string; reason: string }}[];
  charges: number;
}};
export type Outcome = 'paid' | 'duplicate' | 'reconcile' | 'ignored' | 'failed';
"""

HOOK_BUGGY = """{head}
""" + HOOK_TYPES + """
export function handle(event: PaymentEvent, ledger: Ledger): Outcome {{
  const order = ledger.orders.get(event.orderId)!;
  if (event.type === 'succeeded') {{
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }}
  order.status = 'failed';
  return 'failed';
}}
"""

HOOK_FIXED = """{head}
""" + HOOK_TYPES + """
export function handle(event: PaymentEvent, ledger: Ledger): Outcome {{
  if (ledger.processed.has(event.id)) return 'duplicate';
  ledger.processed.add(event.id);
  const order = ledger.orders.get(event.orderId);
  if (!order) {{
    ledger.reconcile.push({{ orderId: event.orderId, eventId: event.id, reason: 'unknown_order' }});
    return 'reconcile';
  }}
  if (event.type === 'succeeded') {{
    if (order.status === 'paid') return 'duplicate';
    if (order.status === 'cancelled') {{
      // Money arrived for an order we already cancelled: a person refunds it.
      ledger.reconcile.push({{ orderId: order.id, eventId: event.id, reason: 'late_success' }});
      return 'reconcile';
    }}
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }}
  if (order.status !== 'pending') return 'ignored'; // an older failure never downgrades a result
  order.status = 'failed';
  return 'failed';
}}
"""

HOOK_AI = """{head}
// {ai}
""" + HOOK_TYPES + """
export function handle(event: PaymentEvent, ledger: Ledger): Outcome {{
  const order = ledger.orders.get(event.orderId);
  if (!order) return 'ignored';
  if (event.type === 'succeeded') {{
    if (order.status === 'cancelled') {{
      ledger.reconcile.push({{ orderId: order.id, eventId: event.id, reason: 'late_success' }});
      return 'reconcile';
    }}
    if (ledger.processed.has(event.id)) return 'duplicate';
    ledger.processed.add(event.id);
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }}
  if (order.status !== 'pending') return 'ignored';
  order.status = 'failed';
  return 'failed';
}}
"""
HOOK_AI_NOTE = ("AICode 초안: 이벤트 id로 중복을 막고 취소된 주문의 성공은 조정 목록에 넣었습니다. 모르는 주문과 조정 목록 중복은 검증하지 않았습니다.",
                "AICode draft: dedupes by event id and routes successes on cancelled orders to reconciliation. Unknown orders and duplicate reconciliation entries were not validated.")

HOOK_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ handle }} from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({{
  orders: new Map(orders.map(([id, status]) => [id, {{ id, status }}])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
}});

test('{t1}', () => {{
  const l = ledger([['ord-1', 'pending']]);
  assert.equal(handle({{ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }}, l), 'paid');
  assert.equal(l.orders.get('ord-1').status, 'paid');
  assert.equal(l.charges, 1);
}});

test('{t2}', () => {{
  const l = ledger([['ord-1', 'pending']]);
  handle({{ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }}, l);
  assert.equal(handle({{ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }}, l), 'duplicate');
  assert.equal(l.charges, 1);
}});

test('{t3}', () => {{
  const l = ledger([['ord-2', 'cancelled']]);
  assert.equal(handle({{ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }}, l), 'reconcile');
  assert.equal(l.orders.get('ord-2').status, 'cancelled');
  assert.equal(l.reconcile.length, 1);
}});

test('{t4}', () => {{
  const l = ledger([['ord-3', 'pending']]);
  handle({{ id: 'ev-3', orderId: 'ord-3', type: 'succeeded' }}, l);
  assert.equal(handle({{ id: 'ev-0', orderId: 'ord-3', type: 'failed' }}, l), 'ignored');
  assert.equal(l.orders.get('ord-3').status, 'paid');
}});
"""
HOOK_T = {
    "t1": ("결제 성공이면 주문이 paid가 된다", "a success marks the order paid"),
    "t2": ("같은 이벤트가 두 번 와도 한 번만 확정한다", "the same event twice is confirmed once"),
    "t3": ("취소된 주문의 늦은 성공은 조정 목록으로 간다", "a late success on a cancelled order goes to reconciliation"),
    "t4": ("늦게 온 실패가 성공을 덮지 않는다", "a late failure doesn't overwrite a success"),
}

CI_HOOK = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ handle }} from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({{
  orders: new Map(orders.map(([id, status]) => [id, {{ id, status }}])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
}});

test('{c1}', () => {{
  const l = ledger([]);
  assert.equal(handle({{ id: 'ev-9', orderId: 'ord-x', type: 'succeeded' }}, l), 'reconcile');
  assert.equal(l.reconcile[0].reason, 'unknown_order');
}});

test('{c2}', () => {{
  const l = ledger([['ord-1', 'pending']]);
  handle({{ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }}, l);
  assert.equal(handle({{ id: 'ev-1b', orderId: 'ord-1', type: 'succeeded' }}, l), 'duplicate');
  assert.equal(l.charges, 1);
}});

test('{c3}', () => {{
  const l = ledger([['ord-2', 'cancelled']]);
  handle({{ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }}, l);
  handle({{ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }}, l);
  assert.equal(l.reconcile.length, 1);
}});
"""
CI_HOOK_T = {
    "c1": ("[CI] 모르는 주문의 이벤트는 버리지 않고 조정 목록에", "[CI] events for unknown orders go to reconciliation, not the bin"),
    "c2": ("[CI] 이미 paid인 주문의 다른 성공 이벤트는 다시 청구하지 않는다", "[CI] another success for a paid order isn't charged again"),
    "c3": ("[CI] 같은 늦은 성공이 두 번 와도 조정 목록엔 한 번", "[CI] the same late success twice is listed once"),
}

# --- Wiki ----------------------------------------------------------------------------------------

RUNBOOK = ("""캠페인 준비 — 봄 한정 20시 오픈

부하
- 평균이 아니라 20:00 첫 1분이 문제다. 작년 첫 1분은 평균의 9배였다.
- 시나리오는 실제 분당 기록을 재현한다. 가장 큰 숫자를 모든 구간에 넣지 않는다.

재고 예약 (src/inventory/reserve.ts)
- reserve는 결제 전에 10분간 한 개를 잡는다. 확인과 선점 사이에 await가 있으면 안 된다.
- 만료된 예약은 재고로 돌아가고, 만료된 예약은 확정할 수 없다.
- 감사 로그 기록이 실패하면 선점을 풀고 false.

가격 캐시 (src/pricing/price_cache.ts)
- 화면 가격은 60초 캐시. 가격을 바꾸면 그 상품의 캐시만 비운다.
- 결제 금액은 캐시를 쓰지 않는다. 조회 속도와 주문 정확도는 다른 지표다.

결제 웹훅 (src/payments/webhook.ts)
- 같은 이벤트 id는 한 번만 처리한다. 이미 paid인 주문은 다시 청구하지 않는다.
- 취소된 주문에 온 성공, 모르는 주문의 이벤트는 버리지 않고 조정 목록(사람 확인)으로.
- 늦게 온 실패는 이미 나온 결과를 덮지 않는다.
""", """Campaign prep — Spring limited, opens 20:00

Load
- The problem isn't the average; it's the first minute at 20:00. Last year it was 9x the average.
- Scenarios replay the real per-minute record. Don't put the biggest number on every interval.

Inventory holds (src/inventory/reserve.ts)
- reserve holds one item for 10 minutes before payment. No await between the check and the claim.
- Expired holds go back to stock, and an expired hold can't be confirmed.
- If the audit log write fails, release the claim and return false.

Price cache (src/pricing/price_cache.ts)
- Display prices are cached for 60 seconds. A price change clears that product only.
- The charged amount never uses the cache. Lookup speed and order accuracy are different metrics.

Payment webhooks (src/payments/webhook.ts)
- Handle each event id once. Never charge an order that's already paid.
- A success for a cancelled order, or an event for an unknown order, goes to the reconciliation list (a person checks it), never the bin.
- A late failure never overwrites a result that already arrived.
""")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main():
    n = 0
    for lang in LANGS:
        base = ROOT / "content" / "commerce-api" / lang / "c05"
        ci = ROOT / "content" / "ci" / lang
        rh, ph, hh = pick(RESERVE_HEAD, lang), pick(PRICE_HEAD, lang), pick(HOOK_HEAD, lang)
        files = {
            base / "reserve.ts": RESERVE_BUGGY.format(head=rh),
            base / "reserve_fixed.ts": RESERVE_FIXED.format(head=rh),
            base / "reserve_ai.ts": RESERVE_AI.format(head=rh, ai=pick(RESERVE_AI_NOTE, lang)),
            base / "reserve.test.ts": fill(RESERVE_TEST, RESERVE_T, lang),
            ci / "c05_02" / "ci_reserve.test.ts": fill(CI_RESERVE, CI_RESERVE_T, lang),
            base / "price_cache.ts": PRICE_BUGGY.format(head=ph),
            base / "price_cache_fixed.ts": PRICE_FIXED.format(head=ph),
            base / "price_cache.test.ts": fill(PRICE_TEST, PRICE_T, lang),
            ci / "c05_03" / "ci_price_cache.test.ts": fill(CI_PRICE, CI_PRICE_T, lang),
            base / "webhook.ts": HOOK_BUGGY.format(head=hh),
            base / "webhook_fixed.ts": HOOK_FIXED.format(head=hh),
            base / "webhook_ai.ts": HOOK_AI.format(head=hh, ai=pick(HOOK_AI_NOTE, lang)),
            base / "webhook.test.ts": fill(HOOK_TEST, HOOK_T, lang),
            ci / "c05_04" / "ci_webhook.test.ts": fill(CI_HOOK, CI_HOOK_T, lang),
            base / "campaign_runbook.txt": pick(RUNBOOK, lang),
        }
        for path, text in files.items():
            write(path, text)
            n += 1
    print(f"{n} chapter-five files written")


if __name__ == "__main__":
    main()
