import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({
  orders: new Map(orders.map(([id, status]) => [id, { id, status }])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
});

test('a success marks the order paid', () => {
  const l = ledger([['ord-1', 'pending']]);
  assert.equal(handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l), 'paid');
  assert.equal(l.orders.get('ord-1').status, 'paid');
  assert.equal(l.charges, 1);
});

test('the same event twice is confirmed once', () => {
  const l = ledger([['ord-1', 'pending']]);
  handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l), 'duplicate');
  assert.equal(l.charges, 1);
});

test('a late success on a cancelled order goes to reconciliation', () => {
  const l = ledger([['ord-2', 'cancelled']]);
  assert.equal(handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l), 'reconcile');
  assert.equal(l.orders.get('ord-2').status, 'cancelled');
  assert.equal(l.reconcile.length, 1);
});

test('a late failure doesn\'t overwrite a success', () => {
  const l = ledger([['ord-3', 'pending']]);
  handle({ id: 'ev-3', orderId: 'ord-3', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-0', orderId: 'ord-3', type: 'failed' }, l), 'ignored');
  assert.equal(l.orders.get('ord-3').status, 'paid');
});
