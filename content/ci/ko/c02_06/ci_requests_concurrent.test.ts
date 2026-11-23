import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';
import { memoryStore } from './request_store.ts';

// 공개된 동시성 계약의 입력을 넓혀 확인한다.
const base = { shopId: 'moonlight', requestKey: 'buy-99', items: [{ sku: 'A', price: 100, quantity: 1 }] };

test('[CI] 다섯 번 동시에 보내도 주문 하나', async () => {
  const store = memoryStore({ delayMs: 10 });
  const orders = await Promise.all(Array.from({ length: 5 }, () => createOrder(structuredClone(base), store as any)));
  assert.equal(new Set(orders.map(order => order.id)).size, 1);
  assert.equal(store.count(), 1);
});
test('[CI] 다른 상점의 같은 키는 동시에 와도 별개', async () => {
  const store = memoryStore();
  const [a, b] = await Promise.all([createOrder(base, store as any), createOrder({ ...base, shopId: 'other' }, store as any)]);
  assert.notEqual(a.id, b.id);
  assert.equal(store.count(), 2);
});
test('[CI] 생성 중인 같은 키에 다른 내용이 오면 충돌', async () => {
  const store = memoryStore({ delayMs: 15 });
  const results = await Promise.allSettled([createOrder(base, store as any), createOrder({ ...base, items: [{ sku: 'A', price: 100, quantity: 2 }] }, store as any)]);
  assert.equal(results[0].status, 'fulfilled');
  assert.equal(results[1].status, 'rejected');
  assert.equal((results[1] as PromiseRejectedResult).reason?.message, 'REQUEST_CONFLICT');
  assert.equal(store.count(), 1);
});
test('[CI] 기다리던 요청이 있어도 실패 후 재시도는 한 번만 생성', async () => {
  const store = memoryStore({ failFirstCreate: true, delayMs: 10 });
  await Promise.allSettled([createOrder(base, store as any), createOrder(base, store as any)]);
  const retry = await createOrder(base, store as any);
  assert.equal(store.count(), 1);
  assert.equal((await createOrder(base, store as any)).id, retry.id);
});
test('[CI] 빈 키는 동시에 와도 주문을 만들지 않는다', async () => {
  const store = memoryStore();
  const results = await Promise.allSettled([createOrder({ ...base, requestKey: ' ' }, store as any), createOrder({ ...base, requestKey: null }, store as any)]);
  assert.ok(results.every(r => r.status === 'rejected' && (r as PromiseRejectedResult).reason?.message === 'REQUEST_KEY_REQUIRED'));
  assert.equal(store.count(), 0);
});
