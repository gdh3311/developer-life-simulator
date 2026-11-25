import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Inventory } from '../src/inventory/reserve.ts';

const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('[CI] 만료된 예약은 재고로 돌아간다', async () => {
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.available(), 1);
  assert.equal(await inv.reserve('o-2'), true);
});

test('[CI] 만료된 예약은 확정할 수 없다', async () => {
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.confirm('o-1'), false);
});

test('[CI] 감사 로그가 실패하면 선점을 풀고 false', async () => {
  const inv = new Inventory(1, clock(), async () => { throw new Error('audit down'); });
  assert.equal(await inv.reserve('o-1'), false);
  assert.equal(inv.available(), 1);
});
