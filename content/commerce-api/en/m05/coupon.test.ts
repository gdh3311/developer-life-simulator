import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/orders/coupon.ts';

test('applies an amount coupon', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});
