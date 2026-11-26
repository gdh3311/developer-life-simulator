import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/shipping/fee.ts';

test('base fee up to 2 kg', () => {
  assert.equal(shippingFee(2), 3000);
});

test('4 kg adds 1,000 won', () => {
  assert.equal(shippingFee(4), 4000);
});
