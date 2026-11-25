"""Generate Chapter 4 (an old decision) content for both languages.

Writes content/commerce-api/{ko,en}/c04/* and hidden CI under content/ci/{ko,en}/c04_03/.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ("ko", "en")


def pick(v, lang):
    return v[0] if lang == "ko" else v[1]


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


# --- M01 refund (with the legacy branch) ---------------------------------------------------

REFUND = ("""// 환불 금액 계산. 2023년 첫 계약 때 만든 모듈을 payments-service에서 옮겨 왔다.
// 정책: Wiki > 환불 계산
export type Order = {{ total: number; legacy?: boolean }};

export function refundAmount(order: Order, ratio: number): number {{
  if (order.legacy) {{
    // {legacy_note}
    return Math.floor((order.total * ratio) / 10) * 10;
  }}
  return Math.round(order.total * ratio);
}}
""", """// Refund amount. Moved from payments-service; first written for the 2023 launch contract.
// Policy: Wiki > Refund calculation
export type Order = {{ total: number; legacy?: boolean }};

export function refundAmount(order: Order, ratio: number): number {{
  if (order.legacy) {{
    // {legacy_note}
    return Math.floor((order.total * ratio) / 10) * 10;
  }}
  return Math.round(order.total * ratio);
}}
""")
LEGACY_NOTE = ("첫 계약 판매자: 10원 단위 내림 (계약서 7조)", "launch-contract sellers: round down to 10 won (contract §7)")

# The mutant the game runs your tests against: the "unused" branch deleted.
REFUND_MUTANT = """export type Order = { total: number; legacy?: boolean };

export function refundAmount(order: Order, ratio: number): number {
  return Math.round(order.total * ratio);
}
"""

CHAR_STARTER = ("""import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ refundAmount }} from '../src/refunds/refund.ts';

// 특성 테스트: 지금 코드가 실제로 하는 일을 그대로 고정한다. 옳고 그름은 나중에 판단한다.
test('{t1}', () => {{
  assert.equal(refundAmount({{ total: 12000 }}, 0.5), 6000);
}});

// TODO: legacy 주문의 동작도 고정하세요. 분기를 지우면 이 파일이 실패해야 합니다.
""", """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ refundAmount }} from '../src/refunds/refund.ts';

// Characterization tests: pin down what the code does today. Judge right or wrong later.
test('{t1}', () => {{
  assert.equal(refundAmount({{ total: 12000 }}, 0.5), 6000);
}});

// TODO: pin the legacy orders' behavior too. Deleting the branch should make this file fail.
""")
CHAR_T1 = ("일반 주문 절반 환불", "regular order, half refund")

CHAR_SOLUTION = ("""import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ refundAmount }} from '../src/refunds/refund.ts';

test('{t1}', () => {{
  assert.equal(refundAmount({{ total: 12000 }}, 0.5), 6000);
}});

test('legacy 주문은 10원 단위로 내린다', () => {{
  assert.equal(refundAmount({{ total: 12345, legacy: true }}, 0.5), 6170);
  assert.equal(refundAmount({{ total: 12345 }}, 0.5), 6173);
}});
""", """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ refundAmount }} from '../src/refunds/refund.ts';

test('{t1}', () => {{
  assert.equal(refundAmount({{ total: 12000 }}, 0.5), 6000);
}});

test('legacy orders round down to 10 won', () => {{
  assert.equal(refundAmount({{ total: 12345, legacy: true }}, 0.5), 6170);
  assert.equal(refundAmount({{ total: 12345 }}, 0.5), 6173);
}});
""")

# Hidden CI for M01: the company's own record of the launch-contract behavior. A PR that deletes
# the legacy branch fails here even if the player's tests don't cover it.
CI_LEGACY = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ refundAmount }} from '../src/refunds/refund.ts';

test('{c1}', () => {{
  assert.equal(refundAmount({{ total: 12345, legacy: true }}, 0.5), 6170);
  assert.equal(refundAmount({{ total: 9999, legacy: true }}, 1), 9990);
}});

test('{c2}', () => {{
  assert.equal(refundAmount({{ total: 12345 }}, 0.5), 6173);
}});
"""
CI_LEGACY_T = {
    "c1": ("[CI] 첫 계약 판매자 환불은 10원 단위 내림 (계약서 7조)", "[CI] launch-contract refunds round down to 10 won (contract §7)"),
    "c2": ("[CI] 일반 주문 환불은 반올림", "[CI] regular refunds round half up"),
}

# --- M03 dual write --------------------------------------------------------------------------

DUAL_HEAD = ("// ATLAS 1단계: 기존 저장소와 새 원장에 함께 기록한다. 전환은 아직 하지 않는다.\n// 규칙: Wiki > ATLAS 이중 기록",
             "// ATLAS stage 1: write to the old store and the new ledger. No cutover yet.\n// Rules: Wiki > ATLAS dual write")

DUAL_BUGGY = """{head}
export type Record = {{ id: string; amount: number }};
export type Store = {{ write(r: Record): Promise<void> }};
export type Result = {{ status: 'ok' | 'partial' | 'failed'; retry: string[] }};

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {{
  await old.write(r);
  try {{
    await ledger.write(r);
  }} catch {{
    // ignore: the ledger is only for comparison
  }}
  return {{ status: 'ok', retry }};
}}
"""

DUAL_FIXED = """{head}
export type Record = {{ id: string; amount: number }};
export type Store = {{ write(r: Record): Promise<void> }};
export type Result = {{ status: 'ok' | 'partial' | 'failed'; retry: string[] }};

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {{
  try {{
    await old.write(r);
  }} catch {{
    // The old store is still the source of truth: nothing was saved.
    return {{ status: 'failed', retry }};
  }}
  try {{
    await ledger.write(r);
  }} catch {{
    // Never lose a comparison record: queue it for reprocessing (once).
    if (!retry.includes(r.id)) retry.push(r.id);
    return {{ status: 'partial', retry }};
  }}
  return {{ status: 'ok', retry }};
}}
"""

DUAL_AI = """{head}
// {ai}
export type Record = {{ id: string; amount: number }};
export type Store = {{ write(r: Record): Promise<void> }};
export type Result = {{ status: 'ok' | 'partial' | 'failed'; retry: string[] }};

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {{
  await old.write(r);
  try {{
    await ledger.write(r);
  }} catch (error) {{
    console.error('ledger write failed', r.id, error);
    retry.push(r.id);
    return {{ status: 'partial', retry }};
  }}
  return {{ status: 'ok', retry }};
}}
"""
AI_NOTE = ("AICode 초안: 원장 실패를 기록하고 재처리 목록에 넣었습니다. 기존 저장소 실패와 중복 재처리는 검증하지 않았습니다.",
           "AICode draft: logs ledger failures and queues them. Old-store failures and duplicate retries were not validated.")

DUAL_TEST = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ writeBoth }} from '../src/atlas/dual_write.ts';

const ok = () => {{ const saved: string[] = []; return {{ saved, write: async (r: any) => {{ saved.push(r.id); }} }}; }};
const broken = () => ({{ write: async () => {{ throw new Error('down'); }} }});

test('{t1}', async () => {{
  const old = ok(), ledger = ok();
  const r = await writeBoth({{ id: 'ord-1', amount: 100 }}, old, ledger, []);
  assert.equal(r.status, 'ok');
  assert.deepEqual(old.saved, ['ord-1']);
  assert.deepEqual(ledger.saved, ['ord-1']);
}});

test('{t2}', async () => {{
  const r = await writeBoth({{ id: 'ord-2', amount: 100 }}, ok(), broken(), []);
  assert.equal(r.status, 'partial');
  assert.deepEqual(r.retry, ['ord-2']);
}});

test('{t3}', async () => {{
  const retry = ['ord-0'];
  const r = await writeBoth({{ id: 'ord-3', amount: 100 }}, ok(), broken(), retry);
  assert.deepEqual(r.retry, ['ord-0', 'ord-3']);
}});

test('{t4}', async () => {{
  const r = await writeBoth({{ id: 'ord-4', amount: 100 }}, ok(), ok(), []);
  assert.deepEqual(r.retry, []);
}});
"""
DUAL_T = {
    "t1": ("둘 다 성공하면 ok", "ok when both writes succeed"),
    "t2": ("원장 실패는 partial이고 재처리 목록에 남는다", "a ledger failure is partial and queued for retry"),
    "t3": ("재처리 목록은 기존 항목을 유지한다", "the retry list keeps existing items"),
    "t4": ("성공하면 재처리 목록에 넣지 않는다", "success adds nothing to the retry list"),
}

CI_DUAL = """import {{ test }} from 'node:test';
import assert from 'node:assert/strict';
import {{ writeBoth }} from '../src/atlas/dual_write.ts';

const ok = () => {{ const saved: string[] = []; return {{ saved, write: async (r: any) => {{ saved.push(r.id); }} }}; }};
const broken = () => ({{ write: async () => {{ throw new Error('down'); }} }});

test('{c1}', async () => {{
  const ledger = ok();
  const r = await writeBoth({{ id: 'ord-9', amount: 100 }}, broken(), ledger, []);
  assert.equal(r.status, 'failed');
  assert.deepEqual(ledger.saved, []);
}});

test('{c2}', async () => {{
  const retry: string[] = [];
  await writeBoth({{ id: 'ord-7', amount: 100 }}, ok(), broken(), retry);
  await writeBoth({{ id: 'ord-7', amount: 100 }}, ok(), broken(), retry);
  assert.deepEqual(retry, ['ord-7']);
}});

test('{c3}', async () => {{
  const r = await writeBoth({{ id: 'ord-8', amount: 100 }}, broken(), broken(), []);
  assert.deepEqual(r.retry, []);
}});
"""
CI_DUAL_T = {
    "c1": ("[CI] 기존 저장소가 실패하면 원장에도 쓰지 않고 failed", "[CI] if the old store fails, skip the ledger and report failed"),
    "c2": ("[CI] 같은 기록은 재처리 목록에 한 번만", "[CI] a record is queued for retry only once"),
    "c3": ("[CI] 저장 자체가 실패한 기록은 재처리 대상이 아니다", "[CI] records that were never saved are not retried"),
}

# --- Wiki --------------------------------------------------------------------------------------

REFUND_POLICY = ("""환불 계산

refundAmount(order, ratio) -> 원 단위 정수
- 일반 주문: 반올림 (Math.round)
- legacy 주문: 10원 단위 내림 — 2023년 첫 계약 판매자 12곳의 계약서 7조

legacy 분기는 아무도 안 쓰는 것처럼 보이지만 첫 계약 판매자의 환불에서 매일 쓰인다.
지우기 전에 특성 테스트로 현재 동작을 고정하고, 계약 만료와 함께 폐기 계획을 세운다.
""", """Refund calculation

refundAmount(order, ratio) -> integer won
- Regular orders: round half up (Math.round)
- Legacy orders: round down to 10 won — §7 of the 2023 launch contract (12 sellers)

The legacy branch looks unused but runs every day for launch-contract refunds.
Pin today's behavior with characterization tests before removing it, and plan the
retirement around the contract's expiry.
""")

ATLAS_DOC = ("""ATLAS 이중 기록

writeBoth(record, old, ledger, retry) -> { status, retry }
1. 기존 저장소가 기준이다. 기존 저장소 쓰기가 실패하면 원장에도 쓰지 않고 status 'failed'.
2. 원장 쓰기만 실패하면 status 'partial', 기록 id를 재처리 목록에 넣는다. 같은 id는 한 번만.
3. 둘 다 성공하면 'ok'. 재처리 목록은 건드리지 않는다.
4. 실패를 조용히 무시하지 않는다. 비교 기록이 빠지면 나중에 전환 판단을 할 수 없다.

이 단계에서는 전환하지 않는다. 원장은 비교용이다.
""", """ATLAS dual write

writeBoth(record, old, ledger, retry) -> { status, retry }
1. The old store is the source of truth. If it fails, don't write the ledger: status 'failed'.
2. If only the ledger fails: status 'partial', and queue the record id for retry. Once per id.
3. If both succeed: 'ok'. Leave the retry list alone.
4. Never swallow failures silently. Missing comparison records make the later cutover decision impossible.

No cutover in this stage. The ledger is for comparison only.
""")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def fill(t, names, lang, **extra):
    values = {k: esc(pick(v, lang)) for k, v in names.items()}
    values.update(extra)
    return t.format(**values)


def main():
    n = 0
    for lang in LANGS:
        base = ROOT / "content" / "commerce-api" / lang / "c04"
        ci = ROOT / "content" / "ci" / lang
        head = pick(DUAL_HEAD, lang)
        files = {
            base / "refund.ts": pick(REFUND, lang).format(legacy_note=pick(LEGACY_NOTE, lang)),
            base / "refund_mutant.ts": REFUND_MUTANT,
            base / "refund_characterization.test.ts": pick(CHAR_STARTER, lang).format(t1=esc(pick(CHAR_T1, lang))),
            base / "refund_characterization_solution.ts": pick(CHAR_SOLUTION, lang).format(t1=esc(pick(CHAR_T1, lang))),
            base / "dual_write.ts": DUAL_BUGGY.format(head=head),
            base / "dual_write_fixed.ts": DUAL_FIXED.format(head=head),
            base / "dual_write_ai.ts": DUAL_AI.format(head=head, ai=pick(AI_NOTE, lang)),
            base / "dual_write.test.ts": fill(DUAL_TEST, DUAL_T, lang),
            ci / "c04_03" / "ci_dual_write.test.ts": fill(CI_DUAL, CI_DUAL_T, lang),
            ci / "c04_01" / "ci_refund_legacy.test.ts": fill(CI_LEGACY, CI_LEGACY_T, lang),
            base / "refund_policy.txt": pick(REFUND_POLICY, lang),
            base / "atlas_policy.txt": pick(ATLAS_DOC, lang),
        }
        for path, text in files.items():
            write(path, text)
            n += 1
    print(f"{n} chapter-four files written")


if __name__ == "__main__":
    main()
