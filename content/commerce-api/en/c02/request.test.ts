import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

const request = () => ({ shopId: 'moonlight', requestKey: 'buy-17', items: [{ sku: 'A', price: 10000, quantity: 1 }] });

test('a new request creates one order', async () => {
  const store = memoryStore();
  const order = await createOrder(request(), store);
  assert.equal(order.id, 'ORD-1');
  assert.equal(store.count(), 1);
});

test('retrying the same request returns the same order', async () => {
  const store = memoryStore();
  const first = await createOrder(request(), store);
  const second = await createOrder(request(), store);
  assert.equal(second.id, first.id);
  assert.equal(store.count(), 1);
});

test('different contents with the same key conflict', async () => {
  const store = memoryStore();
  await createOrder(request(), store);
  await assert.rejects(createOrder({ ...request(), items: [{ sku: 'B', price: 5000, quantity: 2 }] }, store), { message: 'REQUEST_CONFLICT' });
  assert.equal(store.count(), 1);
});

test('different shops may use the same request key', async () => {
  const store = memoryStore();
  const a = await createOrder(request(), store);
  const b = await createOrder({ ...request(), shopId: 'other-shop' }, store);
  assert.notEqual(a.id, b.id);
  assert.equal(store.count(), 2);
});

test('empty request keys do not create orders', async () => {
  const store = memoryStore();
  for (const requestKey of ['', '   ', null, undefined]) {
    await assert.rejects(createOrder({ ...request(), requestKey }, store), { message: 'REQUEST_KEY_REQUIRED' });
  }
  assert.equal(store.count(), 0);
});
