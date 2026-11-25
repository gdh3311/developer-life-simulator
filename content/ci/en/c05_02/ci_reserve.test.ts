import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Inventory } from '../src/inventory/reserve.ts';

const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('[CI] expired holds return to stock', async () => {
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.available(), 1);
  assert.equal(await inv.reserve('o-2'), true);
});

test('[CI] an expired hold cannot be confirmed', async () => {
  const c = clock();
  const inv = new Inventory(1, c);
  await inv.reserve('o-1');
  c.advance(601_000);
  assert.equal(inv.confirm('o-1'), false);
});

test('[CI] if the audit log fails, release the claim and return false', async () => {
  const inv = new Inventory(1, clock(), async () => { throw new Error('audit down'); });
  assert.equal(await inv.reserve('o-1'), false);
  assert.equal(inv.available(), 1);
});
