import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestLog } from '../src/orders/request_log.ts';

const event = (attempt = 1) => ({
  requestId: 'req-8812', shopId: 'moonlight', requestKey: 'buy-17', attempt, result: 'existing' as const, durationMs: 731,
  buyer: { name: 'Mira Test', address: '12 Test-ro', phone: '010-0000-0000' },
  paymentToken: 'tok_test_4242',
  items: [{ sku: 'A', price: 10000, quantity: 1 }],
});

test('{{TL_TRACE}}', () => {
  const text = JSON.stringify(requestLog(event()));
  for (const value of ['req-8812', 'moonlight', 'existing', '731']) assert.ok(text.includes(value), value);
});

test('{{TL_RETRY}}', () => {
  assert.notEqual(JSON.stringify(requestLog(event(1))), JSON.stringify(requestLog(event(2))));
});

test('{{TL_PRIVATE}}', () => {
  const text = JSON.stringify(requestLog(event()));
  for (const value of ['Mira Test', '12 Test-ro', '010-0000-0000', 'tok_test_4242']) assert.ok(!text.includes(value), value);
});
