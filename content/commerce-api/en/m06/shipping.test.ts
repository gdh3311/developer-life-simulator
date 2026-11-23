import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/orders/shipping.ts';

test('free shipping from 50,000 won', () => {
  assert.equal(shippingFee(60000), 0);
});
