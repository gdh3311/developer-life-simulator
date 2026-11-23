import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

const request = () => ({ shopId: 'moonlight', requestKey: 'buy-17', items: [{ sku: 'A', price: 10000, quantity: 1 }] });

test('{{TC_PARALLEL}}', async () => {
  const store = memoryStore();
  const [a, b] = await Promise.all([createOrder(request(), store as any), createOrder(request(), store as any)]);
  assert.equal(a.id, b.id);
  assert.equal(store.count(), 1);
});

test('{{TC_RECOVER}}', async () => {
  const store = memoryStore({ failFirstCreate: true });
  await assert.rejects(createOrder(request(), store as any), { message: 'CREATE_FAILED' });
  const order = await createOrder(request(), store as any);
  assert.equal(order.id, 'ORD-1');
  assert.equal(store.count(), 1);
});

test('{{TC_SEQUENTIAL}}', async () => {
  const store = memoryStore();
  const first = await createOrder(request(), store as any);
  const again = await createOrder(request(), store as any);
  assert.equal(again.id, first.id);
});
