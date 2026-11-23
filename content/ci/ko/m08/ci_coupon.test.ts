import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/orders/coupon.ts';

test('[CI] 정액 쿠폰을 적용한다', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});

test('[CI] 정률 쿠폰은 퍼센트로 계산한다', () => {
  assert.equal(applyCoupon(10000, { type: 'percent', value: 10 }), 9000);
});

test('[CI] 결제 금액은 0원 미만이 될 수 없다', () => {
  assert.equal(applyCoupon(2000, { type: 'amount', value: 5000 }), 0);
});

test('[CI] 정률 쿠폰 원 단위 이하는 버린다', () => {
  assert.equal(applyCoupon(9999, { type: 'percent', value: 15 }), 8500);
});
