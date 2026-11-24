import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestCancel } from '../src/preorder/cancel.ts';

test('결제 전 취소는 그냥 취소다', () => {
  assert.deepEqual(requestCancel({ paid: false, stage: 'placed' }), { state: 'cancelled', refund: false });
});

test('결제 후 취소는 환불 요청으로 따로 남는다', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'placed' }), { state: 'refund_requested', refund: true });
});

test('배송 준비 중이면 판매자 확인이 필요하다', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'preparing' }), { state: 'needs_review', refund: false });
});

test('발송된 주문은 취소할 수 없다', () => {
  assert.deepEqual(requestCancel({ paid: true, stage: 'shipped' }), { state: 'rejected', refund: false });
});
