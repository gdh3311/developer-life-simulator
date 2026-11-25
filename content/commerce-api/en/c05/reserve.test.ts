import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Inventory } from '../src/inventory/reserve.ts';

const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('reserving then confirming sells one item', async () => {
  const inv = new Inventory(2, clock());
  assert.equal(await inv.reserve('o-1'), true);
  assert.equal(inv.confirm('o-1'), true);
  assert.equal(inv.available(), 1);
});

test('cancelling releases the hold', async () => {
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(inv.cancel('o-1'), true);
  assert.equal(inv.available(), 1);
});

test('three concurrent holds on the last item: only one succeeds', async () => {
  const inv = new Inventory(1, clock());
  const results = await Promise.all(['o-1', 'o-2', 'o-3'].map(id => inv.reserve(id)));
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal(inv.available(), 0);
});

test('holds fail when sold out', async () => {
  const inv = new Inventory(1, clock());
  await inv.reserve('o-1');
  assert.equal(await inv.reserve('o-2'), false);
});
