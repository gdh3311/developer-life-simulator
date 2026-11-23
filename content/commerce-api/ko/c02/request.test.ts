import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

const request = () => ({ shopId: 'moonlight', requestKey: 'buy-17', items: [{ sku: 'A', price: 10000, quantity: 1 }] });

test('새 요청은 주문 하나를 생성한다', async () => {
  const store = memoryStore();
  const order = await createOrder(request(), store);
  assert.equal(order.id, 'ORD-1');
  assert.equal(store.count(), 1);
});

test('같은 요청을 재전송해도 같은 주문이다', async () => {
  const store = memoryStore();
  const first = await createOrder(request(), store);
  const second = await createOrder(request(), store);
  assert.equal(second.id, first.id);
  assert.equal(store.count(), 1);
});

test('같은 키에 다른 내용은 충돌이다', async () => {
  const store = memoryStore();
  await createOrder(request(), store);
  await assert.rejects(createOrder({ ...request(), items: [{ sku: 'B', price: 5000, quantity: 2 }] }, store), { message: 'REQUEST_CONFLICT' });
  assert.equal(store.count(), 1);
});

test('상점이 다르면 같은 키도 별개다', async () => {
  const store = memoryStore();
  const a = await createOrder(request(), store);
  const b = await createOrder({ ...request(), shopId: 'other-shop' }, store);
  assert.notEqual(a.id, b.id);
  assert.equal(store.count(), 2);
});

test('비어 있는 요청 키는 주문을 만들지 않는다', async () => {
  const store = memoryStore();
  for (const requestKey of ['', '   ', null, undefined]) {
    await assert.rejects(createOrder({ ...request(), requestKey }, store), { message: 'REQUEST_KEY_REQUIRED' });
  }
  assert.equal(store.count(), 0);
});
