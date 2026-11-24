import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestCancel } from '../src/preorder/cancel.ts';

test('[CI] unpaid orders in preparation still need review', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'preparing' }), { state: 'needs_review', refund: false });
});

test('[CI] unpaid shipped orders are rejected too', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'shipped' }), { state: 'rejected', refund: false });
});

test('[CI] automatic refunds only for refund requests', () => {
  for (const stage of ['placed', 'preparing', 'shipped'] as const) {
    const r = requestCancel({ paid: true, stage });
    assert.equal(r.refund, r.state === 'refund_requested');
  }
});
