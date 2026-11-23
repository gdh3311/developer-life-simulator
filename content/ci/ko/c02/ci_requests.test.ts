import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';

// 공개 정책의 순차 호출만 검증한다. 동시성은 아직 요구하지 않는다.
function independentStore() {
  const entries = new Map();
  let count = 0;
  return {
    get: (key: string) => entries.get(key),
    set: (key: string, entry: unknown) => { entries.set(key, entry); },
    create: async (request: any) => ({ id: `CI-${++count}`, shopId: request.shopId, items: structuredClone(request.items) }),
    count: () => count,
  };
}
const base = { shopId: 'moonlight', requestKey: 'buy-17', items: [{ sku: 'A', price: 100, quantity: 1 }] };

test('[CI] 복사된 요청을 반복해도 주문 하나', async () => {
  const store = independentStore();
  const first = await createOrder(base, store);
  for (let n = 0; n < 3; n++) assert.equal((await createOrder(structuredClone(base), store)).id, first.id);
  assert.equal(store.count(), 1);
});
test('[CI] 상점 ID와 요청 키는 독립적인 쌍이다', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, shopId: 'shop:a', requestKey: 'b' }, store);
  const b = await createOrder({ ...base, shopId: 'shop', requestKey: 'a:b' }, store);
  assert.notEqual(a.id, b.id);
});
test('[CI] 수량 변경도 다른 주문 내용이다', async () => {
  const store = independentStore();
  await createOrder(base, store);
  await assert.rejects(createOrder({ ...base, items: [{ ...base.items[0], quantity: 2 }] }, store), { message: 'REQUEST_CONFLICT' });
  assert.equal(store.count(), 1);
});
test('[CI] 키 공백 정규화와 빈 키 검증', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, requestKey: '  buy-17\t' }, store);
  const b = await createOrder(base, store);
  assert.equal(a.id, b.id);
  await assert.rejects(createOrder({ ...base, requestKey: '\t\n' }, store), { message: 'REQUEST_KEY_REQUIRED' });
});
