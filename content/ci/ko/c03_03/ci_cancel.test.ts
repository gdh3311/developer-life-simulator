import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestCancel } from '../src/preorder/cancel.ts';

test('[CI] 결제 전이라도 배송 준비 중이면 판매자 확인', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'preparing' }), { state: 'needs_review', refund: false });
});

test('[CI] 결제 전 발송 주문도 거절', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'shipped' }), { state: 'rejected', refund: false });
});

test('[CI] 자동 환불은 환불 요청 상태에서만', () => {
  for (const stage of ['placed', 'preparing', 'shipped'] as const) {
    const r = requestCancel({ paid: true, stage });
    assert.equal(r.refund, r.state === 'refund_requested');
  }
});
