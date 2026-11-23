import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';

// Checks the published sequential contract; concurrency is not required yet.
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

test('[CI] repeated cloned requests create only one order', async () => {
  const store = independentStore();
  const first = await createOrder(base, store);
  for (let n = 0; n < 3; n++) assert.equal((await createOrder(structuredClone(base), store)).id, first.id);
  assert.equal(store.count(), 1);
});
test('[CI] shop ID and request key form an independent pair', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, shopId: 'shop:a', requestKey: 'b' }, store);
  const b = await createOrder({ ...base, shopId: 'shop', requestKey: 'a:b' }, store);
  assert.notEqual(a.id, b.id);
});
test('[CI] a quantity change is different request content', async () => {
  const store = independentStore();
  await createOrder(base, store);
  await assert.rejects(createOrder({ ...base, items: [{ ...base.items[0], quantity: 2 }] }, store), { message: 'REQUEST_CONFLICT' });
  assert.equal(store.count(), 1);
});
test('[CI] normalize key whitespace and reject empty keys', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, requestKey: '  buy-17\t' }, store);
  const b = await createOrder(base, store);
  assert.equal(a.id, b.id);
  await assert.rejects(createOrder({ ...base, requestKey: '\t\n' }, store), { message: 'REQUEST_KEY_REQUIRED' });
});
