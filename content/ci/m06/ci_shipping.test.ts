import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/orders/shipping.ts';
import * as orders from '../src/orders/orders.ts';

const items = (price: number) => [{ sku: 'A', price, quantity: 1 }];

test('[CI] 정확히 50,000원이면 무료 배송', () => {
  assert.equal(shippingFee(50000), 0);
});
test('[CI] 49,999원이면 기본 배송비 3,000원', () => {
  assert.equal(shippingFee(49999), 3000);
});
test('[CI] 도서산간은 무료 배송이어도 5,000원 추가', () => {
  assert.equal(shippingFee(60000, 'remote'), 5000);
  assert.equal(shippingFee(10000, 'remote'), 8000);
});
test('[CI] 빈 주문(0원)은 배송비 없음', () => {
  assert.equal(shippingFee(0), 0);
});
test('[CI] orderTotal 은 배송비를 포함한다', () => {
  assert.equal(orders.orderTotal(items(2500)), 5500);
  assert.equal(orders.orderTotal(items(60000)), 60000);
  // @ts-ignore region parameter
  assert.equal(orders.orderTotal(items(10000), 'remote'), 18000);
});
test('[CI] main의 subtotal() 리팩터링이 유지된다', () => {
  // @ts-ignore may not exist on an outdated branch
  const subtotal = orders.subtotal;
  assert.equal(typeof subtotal, 'function', 'main에 있는 subtotal()이 이 브랜치에 없습니다. main을 병합하세요.');
  assert.equal(subtotal(items(1234)), 1234);
});
