import { test } from 'node:test';
import assert from 'node:assert/strict';
import { screenFor } from '../src/orders/order_status.ts';

test('a created order is confirmed with its number', () => {
  assert.deepEqual(screenFor({ kind: 'created', orderId: 'ORD-1' }), { state: 'confirmed', orderId: 'ORD-1', canRetry: false, keepKey: true });
});

test('an existing order is confirmed with the same number', () => {
  assert.equal(screenFor({ kind: 'existing', orderId: 'ORD-1' }).orderId, 'ORD-1');
});

test('a content conflict asks for review with a new key', () => {
  const screen = screenFor({ kind: 'conflict' });
  assert.equal(screen.state, 'review');
  assert.equal(screen.keepKey, false);
});

test('an unknown result is checking, not failure, and keeps the key', () => {
  const screen = screenFor({ kind: 'timeout' });
  assert.notEqual(screen.state, 'failed');
  assert.equal(screen.keepKey, true);
});
