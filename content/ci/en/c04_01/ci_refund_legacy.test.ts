import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

test('[CI] launch-contract refunds round down to 10 won (contract §7)', () => {
  assert.equal(refundAmount({ total: 12345, legacy: true }, 0.5), 6170);
  assert.equal(refundAmount({ total: 9999, legacy: true }, 1), 9990);
});

test('[CI] regular refunds round half up', () => {
  assert.equal(refundAmount({ total: 12345 }, 0.5), 6173);
});
