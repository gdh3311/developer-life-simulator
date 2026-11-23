import { test } from 'node:test';
import assert from 'node:assert/strict';
import { screenFor } from '../src/orders/order_status.ts';

test('{{TS_CONFIRMED}}', () => {
  assert.deepEqual(screenFor({ kind: 'created', orderId: 'ORD-1' }), { state: 'confirmed', orderId: 'ORD-1', canRetry: false, keepKey: true });
});

test('{{TS_EXISTING}}', () => {
  assert.equal(screenFor({ kind: 'existing', orderId: 'ORD-1' }).orderId, 'ORD-1');
});

test('{{TS_CONFLICT}}', () => {
  const screen = screenFor({ kind: 'conflict' });
  assert.equal(screen.state, 'review');
  assert.equal(screen.keepKey, false);
});

test('{{TS_UNKNOWN}}', () => {
  const screen = screenFor({ kind: 'timeout' });
  assert.notEqual(screen.state, 'failed');
  assert.equal(screen.keepKey, true);
});
