import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOrder } from '../src/orders/request.ts';

// {{CI_SCOPE}}
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

test('{{C_REPEAT}}', async () => {
  const store = independentStore();
  const first = await createOrder(base, store);
  for (let n = 0; n < 3; n++) assert.equal((await createOrder(structuredClone(base), store)).id, first.id);
  assert.equal(store.count(), 1);
});
test('{{C_BOUNDARY}}', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, shopId: 'shop:a', requestKey: 'b' }, store);
  const b = await createOrder({ ...base, shopId: 'shop', requestKey: 'a:b' }, store);
  assert.notEqual(a.id, b.id);
});
test('{{C_CONFLICT}}', async () => {
  const store = independentStore();
  await createOrder(base, store);
  await assert.rejects(createOrder({ ...base, items: [{ ...base.items[0], quantity: 2 }] }, store), { message: 'REQUEST_CONFLICT' });
  assert.equal(store.count(), 1);
});
test('{{C_KEY}}', async () => {
  const store = independentStore();
  const a = await createOrder({ ...base, requestKey: '  buy-17\t' }, store);
  const b = await createOrder(base, store);
  assert.equal(a.id, b.id);
  await assert.rejects(createOrder({ ...base, requestKey: '\t\n' }, store), { message: 'REQUEST_KEY_REQUIRED' });
});
