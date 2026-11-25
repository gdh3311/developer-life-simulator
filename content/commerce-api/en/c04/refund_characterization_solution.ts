import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

test('regular order, half refund', () => {
  assert.equal(refundAmount({ total: 12000 }, 0.5), 6000);
});

test('legacy orders round down to 10 won', () => {
  assert.equal(refundAmount({ total: 12345, legacy: true }, 0.5), 6170);
  assert.equal(refundAmount({ total: 12345 }, 0.5), 6173);
});
