import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({
  orders: new Map(orders.map(([id, status]) => [id, { id, status }])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
});

test('[CI] events for unknown orders go to reconciliation, not the bin', () => {
  const l = ledger([]);
  assert.equal(handle({ id: 'ev-9', orderId: 'ord-x', type: 'succeeded' }, l), 'reconcile');
  assert.equal(l.reconcile[0].reason, 'unknown_order');
});

test('[CI] another success for a paid order isn\'t charged again', () => {
  const l = ledger([['ord-1', 'pending']]);
  handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-1b', orderId: 'ord-1', type: 'succeeded' }, l), 'duplicate');
  assert.equal(l.charges, 1);
});

test('[CI] the same late success twice is listed once', () => {
  const l = ledger([['ord-2', 'cancelled']]);
  handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l);
  handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l);
  assert.equal(l.reconcile.length, 1);
});
