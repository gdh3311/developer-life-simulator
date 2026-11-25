import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Inventory } from '../src/inventory/reserve.ts';

const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('예약 후 확정하면 재고가 하나 줄어든다', async () => {
  const inv = new Inventory(2, clock());
  assert.equal(await inv.reserve('o-1'), true);
  assert.equal(inv.confirm('o-1'), true);
  assert.equal(inv.available(), 1);
});

test('취소하면 예약이 풀린다', async () => {
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(inv.cancel('o-1'), true);
  assert.equal(inv.available(), 1);
});

test('마지막 한 개에 동시 예약 세 건이 오면 하나만 성공한다', async () => {
  const inv = new Inventory(1, clock());
  const results = await Promise.all(['o-1', 'o-2', 'o-3'].map(id => inv.reserve(id)));
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal(inv.available(), 0);
});

test('품절이면 예약이 실패한다', async () => {
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(await inv.reserve('o-2'), false);
});
