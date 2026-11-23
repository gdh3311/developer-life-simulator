import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/orders/coupon.ts';

test('applies an amount coupon', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});

test('percent coupons use a percentage', () => {
  assert.equal(applyCoupon(10000, { type: 'percent', value: 10 }), 9000);
});

test('the charge never goes below zero', () => {
  assert.equal(applyCoupon(2000, { type: 'amount', value: 5000 }), 0);
});
