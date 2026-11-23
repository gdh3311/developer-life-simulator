import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestLog } from '../src/orders/request_log.ts';

// Applies the published principle to new inputs: keep only allowed fields.
const extended = (attempt: number, result = 'error') => ({
  requestId: 'req-31', shopId: 'shop-77', requestKey: 'k-9', attempt, result, durationMs: 1204,
  buyer: { name: 'Mina Sample', address: '9 Sample-gil', phone: '010-1111-2222' },
  paymentToken: 'tok_ci_9999',
  buyerEmail: 'sample@example.test',
  cardLast4: '4242',
  notes: 'gate code 0420',
  items: [{ sku: 'Z', price: 1, quantity: 1 }],
});

test('[CI] sensitive fields added later never leak', () => {
  const text = JSON.stringify(requestLog(extended(1) as any));
  for (const value of ['sample@example.test', '4242', 'gate code 0420', 'Mina Sample', '9 Sample-gil', 'tok_ci_9999']) assert.ok(!text.includes(value), value);
});
test('[CI] failures keep tracing information too', () => {
  const text = JSON.stringify(requestLog(extended(1) as any));
  for (const value of ['req-31', 'shop-77', 'error', '1204']) assert.ok(text.includes(value), value);
});
test('[CI] the first and third attempts differ', () => {
  assert.notEqual(JSON.stringify(requestLog(extended(1) as any)), JSON.stringify(requestLog(extended(3) as any)));
});
