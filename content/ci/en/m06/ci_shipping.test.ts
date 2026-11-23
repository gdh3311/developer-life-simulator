import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/orders/shipping.ts';
import * as orders from '../src/orders/orders.ts';

const items = (price: number) => [{ sku: 'A', price, quantity: 1 }];

test('[CI] exactly 50,000 won ships free', () => {
  assert.equal(shippingFee(50000), 0);
});
test('[CI] 49,999 won pays the 3,000 won base fee', () => {
  assert.equal(shippingFee(49999), 3000);
});
test('[CI] remote areas always add 5,000 won', () => {
  assert.equal(shippingFee(60000, 'remote'), 5000);
  assert.equal(shippingFee(10000, 'remote'), 8000);
});
test('[CI] an empty order (0 won) has no fee', () => {
  assert.equal(shippingFee(0), 0);
});
test('[CI] orderTotal includes shipping', () => {
  assert.equal(orders.orderTotal(items(2500)), 5500);
  assert.equal(orders.orderTotal(items(60000)), 60000);
  // @ts-ignore region parameter
  assert.equal(orders.orderTotal(items(10000), 'remote'), 18000);
});
test('[CI] the subtotal() refactor from main is kept', () => {
  // @ts-ignore may not exist on an outdated branch
  const subtotal = orders.subtotal;
  assert.equal(typeof subtotal, 'function', 'subtotal() from main is missing on this branch. Merge main into it.');
  assert.equal(subtotal(items(1234)), 1234);
});
