import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/orders/coupon.ts';

test('[CI] applies an amount coupon', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});

test('[CI] percent coupons use a percentage', () => {
  assert.equal(applyCoupon(10000, { type: 'percent', value: 10 }), 9000);
});

test('[CI] the charge never goes below zero', () => {
  assert.equal(applyCoupon(2000, { type: 'amount', value: 5000 }), 0);
});

test('[CI] percent discounts round down to whole won', () => {
  assert.equal(applyCoupon(9999, { type: 'percent', value: 15 }), 8500);
});
