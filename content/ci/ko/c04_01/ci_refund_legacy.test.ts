import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

test('[CI] 첫 계약 판매자 환불은 10원 단위 내림 (계약서 7조)', () => {
  assert.equal(refundAmount({ total: 12345, legacy: true }, 0.5), 6170);
  assert.equal(refundAmount({ total: 9999, legacy: true }, 1), 9990);
});

test('[CI] 일반 주문 환불은 반올림', () => {
  assert.equal(refundAmount({ total: 12345 }, 0.5), 6173);
});
