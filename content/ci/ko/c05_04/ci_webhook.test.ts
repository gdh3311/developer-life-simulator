import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({
  orders: new Map(orders.map(([id, status]) => [id, { id, status }])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
});

test('[CI] 모르는 주문의 이벤트는 버리지 않고 조정 목록에', () => {
  const l = ledger([]);
  assert.equal(handle({ id: 'ev-9', orderId: 'ord-x', type: 'succeeded' }, l), 'reconcile');
  assert.equal(l.reconcile[0].reason, 'unknown_order');
});

test('[CI] 이미 paid인 주문의 다른 성공 이벤트는 다시 청구하지 않는다', () => {
  const l = ledger([['ord-1', 'pending']]);
  handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-1b', orderId: 'ord-1', type: 'succeeded' }, l), 'duplicate');
  assert.equal(l.charges, 1);
});

test('[CI] 같은 늦은 성공이 두 번 와도 조정 목록엔 한 번', () => {
  const l = ledger([['ord-2', 'cancelled']]);
  handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l);
  handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l);
  assert.equal(l.reconcile.length, 1);
});
