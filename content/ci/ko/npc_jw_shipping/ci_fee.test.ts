import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/shipping/fee.ts';

test('[CI] 2.3kg은 3kg으로 계산 (모자란 무게 올림)', () => {
  assert.equal(shippingFee(2.3), 3500);
});

test('[CI] 1kg 주문도 기본 배송비 (음수 추가 요금 없음)', () => {
  assert.equal(shippingFee(1), 3000);
});
