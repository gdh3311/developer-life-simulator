import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';

try {
  const [modulePath, optionsPath] = process.argv.slice(2);
  const options = JSON.parse(readFileSync(optionsPath, 'utf8'));
  const { createOrder } = await import(pathToFileURL(modulePath).href);
  const entries = new Map();
  const created = [];
  const store = {
    get: key => entries.get(key),
    set: (key, entry) => entries.set(key, entry),
    create: async request => {
      const order = { id: `ORD-${created.length + 1}`, shopId: request.shopId, items: structuredClone(request.items) };
      created.push(order);
      return order;
    },
  };
  // Virtual response conditions schedule sequential calls; no external network is used.
  const attempts = options.clicks + (options.network === 'slow' && options.retry ? 1 : 0);
  const responses = [];
  for (let n = 0; n < attempts; n++) {
    const key = options.keys === 'same' ? 'buy-17' : `buy-17-${n}`;
    const order = await createOrder({ shopId: 'moonlight', requestKey: key, items: [{ sku: 'A', price: 10000, quantity: 1 }] }, store);
    responses.push({ attempt: n + 1, virtualMs: n * 700, key, orderId: order.id });
  }
  console.log('CODIEN_PROBE=' + JSON.stringify({ ok: true, attempts, created: created.length, responses }));
} catch (error) {
  console.log('CODIEN_PROBE=' + JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
  process.exitCode = 1;
}
