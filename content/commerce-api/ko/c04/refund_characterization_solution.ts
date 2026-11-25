import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

test('일반 주문 절반 환불', () => {
  assert.equal(refundAmount({ total: 12000 }, 0.5), 6000);
});

test('legacy 주문은 10원 단위로 내린다', () => {
  assert.equal(refundAmount({ total: 12345, legacy: true }, 0.5), 6170);
  assert.equal(refundAmount({ total: 12345 }, 0.5), 6173);
});
