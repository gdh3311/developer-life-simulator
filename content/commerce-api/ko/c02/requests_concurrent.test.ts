import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

const request = () => ({ shopId: 'moonlight', requestKey: 'buy-17', items: [{ sku: 'A', price: 10000, quantity: 1 }] });

test('동시에 두 번 보내도 주문은 하나다', async () => {
  const store = memoryStore();
  const [a, b] = await Promise.all([createOrder(request(), store as any), createOrder(request(), store as any)]);
  assert.equal(a.id, b.id);
  assert.equal(store.count(), 1);
});

test('생성이 실패해도 선점이 남지 않아 재시도할 수 있다', async () => {
  const store = memoryStore({ failFirstCreate: true });
  await assert.rejects(createOrder(request(), store as any), { message: 'CREATE_FAILED' });
  const order = await createOrder(request(), store as any);
  assert.equal(order.id, 'ORD-1');
  assert.equal(store.count(), 1);
});

test('순차 재시도 계약은 그대로 유지된다', async () => {
  const store = memoryStore();
  const first = await createOrder(request(), store as any);
  const again = await createOrder(request(), store as any);
  assert.equal(again.id, first.id);
});
