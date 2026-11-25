import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/payments/webhook.ts';

const ledger = (orders: [string, string][]) => ({
  orders: new Map(orders.map(([id, status]) => [id, { id, status }])) as any,
  processed: new Set<string>(), reconcile: [] as any[], charges: 0,
});

test('결제 성공이면 주문이 paid가 된다', () => {
  const l = ledger([['ord-1', 'pending']]);
  assert.equal(handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l), 'paid');
  assert.equal(l.orders.get('ord-1').status, 'paid');
  assert.equal(l.charges, 1);
});

test('같은 이벤트가 두 번 와도 한 번만 확정한다', () => {
  const l = ledger([['ord-1', 'pending']]);
  handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-1', orderId: 'ord-1', type: 'succeeded' }, l), 'duplicate');
  assert.equal(l.charges, 1);
});

test('취소된 주문의 늦은 성공은 조정 목록으로 간다', () => {
  const l = ledger([['ord-2', 'cancelled']]);
  assert.equal(handle({ id: 'ev-2', orderId: 'ord-2', type: 'succeeded' }, l), 'reconcile');
  assert.equal(l.orders.get('ord-2').status, 'cancelled');
  assert.equal(l.reconcile.length, 1);
});

test('늦게 온 실패가 성공을 덮지 않는다', () => {
  const l = ledger([['ord-3', 'pending']]);
  handle({ id: 'ev-3', orderId: 'ord-3', type: 'succeeded' }, l);
  assert.equal(handle({ id: 'ev-0', orderId: 'ord-3', type: 'failed' }, l), 'ignored');
  assert.equal(l.orders.get('ord-3').status, 'paid');
});
