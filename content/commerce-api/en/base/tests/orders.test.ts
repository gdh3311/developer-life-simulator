import { test } from 'node:test';
import assert from 'node:assert/strict';
import { orderTotal } from '../src/orders/orders.ts';

test('calculates the order total', () => {
  assert.equal(orderTotal([{ sku: 'A', price: 1000, quantity: 2 }, { sku: 'B', price: 500, quantity: 1 }]), 2500);
});
