import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';

try {
  const [modulePath, optionsPath] = process.argv.slice(2);
  const options = JSON.parse(readFileSync(optionsPath, 'utf8'));
  const { createOrder } = await import(pathToFileURL(modulePath).href);
  const entries = new Map();
  const pending = new Map();
  const created = [];
  // Same contract as tests/request_store.ts: get/set for sequential code, claim/complete/release for atomic code.
  const store = {
    get: key => entries.get(key),
    set: (key, entry) => entries.set(key, entry),
    claim(key, fingerprint) {
      const done = entries.get(key);
      if (done) return { status: 'done', fingerprint: done.fingerprint, order: done.order };
      const running = pending.get(key);
      if (running) return { status: 'pending', fingerprint: running.fingerprint, wait: running.wait };
      let resolve = () => {};
      let reject = () => {};
      const wait = new Promise((ok, fail) => { resolve = ok; reject = fail; });
      wait.catch(() => {});
      pending.set(key, { fingerprint, wait, resolve, reject });
      return { status: 'new' };
    },
    complete(key, order) {
      const running = pending.get(key);
      pending.delete(key);
      if (running) { entries.set(key, { fingerprint: running.fingerprint, order }); running.resolve(order); }
    },
    release(key, error) {
      const running = pending.get(key);
      pending.delete(key);
      if (running) running.reject(error ?? new Error('CREATE_FAILED'));
    },
    create: async request => {
      await new Promise(done => setTimeout(done, 5));
      const order = { id: `ORD-${created.length + 1}`, shopId: request.shopId, items: structuredClone(request.items) };
      created.push(order);
      return order;
    },
  };
  // Virtual response conditions; no external network is used.
  const attempts = options.clicks + (options.network === 'slow' && options.retry ? 1 : 0);
  const call = n => {
    const key = options.keys === 'same' ? 'buy-17' : `buy-17-${n}`;
    return createOrder({ shopId: 'moonlight', requestKey: key, items: [{ sku: 'A', price: 10000, quantity: 1 }] }, store)
      .then(order => ({ attempt: n + 1, virtualMs: options.timing === 'concurrent' ? 0 : n * 700, key, orderId: order.id }));
  };
  const responses = [];
  if (options.timing === 'concurrent') {
    responses.push(...await Promise.all(Array.from({ length: attempts }, (_, n) => call(n))));
  } else {
    for (let n = 0; n < attempts; n++) responses.push(await call(n));
  }
  console.log('CODIEN_PROBE=' + JSON.stringify({ ok: true, attempts, created: created.length, responses }));
} catch (error) {
  console.log('CODIEN_PROBE=' + JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
  process.exitCode = 1;
}
