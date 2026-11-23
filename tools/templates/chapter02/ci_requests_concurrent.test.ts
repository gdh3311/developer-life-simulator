import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

// {{CC_SCOPE}}
const base = { shopId: 'moonlight', requestKey: 'buy-99', items: [{ sku: 'A', price: 100, quantity: 1 }] };

test('{{CC_FIVE}}', async () => {
  const store = memoryStore({ delayMs: 10 });
  const orders = await Promise.all(Array.from({ length: 5 }, () => createOrder(structuredClone(base), store as any)));
  assert.equal(new Set(orders.map(order => order.id)).size, 1);
  assert.equal(store.count(), 1);
});
test('{{CC_SHOPS}}', async () => {
  const store = memoryStore();
  const [a, b] = await Promise.all([createOrder(base, store as any), createOrder({ ...base, shopId: 'other' }, store as any)]);
  assert.notEqual(a.id, b.id);
  assert.equal(store.count(), 2);
});
test('{{CC_PENDING_CONFLICT}}', async () => {
  const store = memoryStore({ delayMs: 15 });
  const results = await Promise.allSettled([createOrder(base, store as any), createOrder({ ...base, items: [{ sku: 'A', price: 100, quantity: 2 }] }, store as any)]);
  assert.equal(results[0].status, 'fulfilled');
  assert.equal(results[1].status, 'rejected');
  assert.equal((results[1] as PromiseRejectedResult).reason?.message, 'REQUEST_CONFLICT');
  assert.equal(store.count(), 1);
});
test('{{CC_FAIL_WAITER}}', async () => {
  const store = memoryStore({ failFirstCreate: true, delayMs: 10 });
  await Promise.allSettled([createOrder(base, store as any), createOrder(base, store as any)]);
  const retry = await createOrder(base, store as any);
  assert.equal(store.count(), 1);
  assert.equal((await createOrder(base, store as any)).id, retry.id);
});
test('{{CC_EMPTY}}', async () => {
  const store = memoryStore();
  const results = await Promise.allSettled([createOrder({ ...base, requestKey: ' ' }, store as any), createOrder({ ...base, requestKey: null }, store as any)]);
  assert.ok(results.every(r => r.status === 'rejected' && (r as PromiseRejectedResult).reason?.message === 'REQUEST_KEY_REQUIRED'));
  assert.equal(store.count(), 0);
});
