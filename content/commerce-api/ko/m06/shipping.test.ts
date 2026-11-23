import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/orders/shipping.ts';

test('5만원 이상이면 무료 배송', () => {
  assert.equal(shippingFee(60000), 0);
});
