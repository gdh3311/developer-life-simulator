import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestCancel } from '../src/preorder/cancel.ts';

test('cancelling before payment is a plain cancel', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'placed' }), { state: 'cancelled', refund: false });
});

test('cancelling after payment becomes a refund request', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'placed' }), { state: 'refund_requested', refund: true });
});

test('orders in preparation need the seller\'s review', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'preparing' }), { state: 'needs_review', refund: false });
});

test('shipped orders cannot be cancelled', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'shipped' }), { state: 'rejected', refund: false });
});
