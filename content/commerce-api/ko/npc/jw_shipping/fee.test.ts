import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/shipping/fee.ts';

test('2kg까지는 기본 배송비', () => {
  assert.equal(shippingFee(2), 3000);
});

test('4kg은 1,000원 추가', () => {
  assert.equal(shippingFee(4), 4000);
});
