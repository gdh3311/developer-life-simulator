import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

// Characterization tests: pin down what the code does today. Judge right or wrong later.
test('regular order, half refund', () => {
  assert.equal(refundAmount({ total: 12000 }, 0.5), 6000);
});

// TODO: pin the legacy orders' behavior too. Deleting the branch should make this file fail.
