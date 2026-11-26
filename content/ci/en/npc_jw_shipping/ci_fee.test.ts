import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/shipping/fee.ts';

test('[CI] 2.3 kg is charged as 3 kg (partial kg rounds up)', () => {
  assert.equal(shippingFee(2.3), 3500);
});

test('[CI] a 1 kg order pays the base fee (no negative extra)', () => {
  assert.equal(shippingFee(1), 3000);
});
