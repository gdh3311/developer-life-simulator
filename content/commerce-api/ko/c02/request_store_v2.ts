import type { OrderRequest, Entry, Order } from '../src/orders/request.ts';

// 테스트용 저장소. claim은 원자적이다: 같은 키를 동시에 선점할 수 있는 요청은 하나뿐이다.
export type Claim =
  | { status: 'new' }
  | { status: 'pending'; fingerprint: string; wait: Promise<Order> }
  | { status: 'done'; fingerprint: string; order: Order };

export function memoryStore(options: { failFirstCreate?: boolean; delayMs?: number } = {}) {
  const entries = new Map<string, Entry>();
  const pending = new Map<string, { fingerprint: string; wait: Promise<Order>; resolve: (order: Order) => void; reject: (error: unknown) => void }>();
  let created = 0;
  let attempts = 0;
  return {
    get: (key: string) => entries.get(key),
    set: (key: string, entry: Entry) => { entries.set(key, entry); },
    claim(key: string, fingerprint: string): Claim {
      const done = entries.get(key);
      if (done) return { status: 'done', fingerprint: done.fingerprint, order: done.order };
      const running = pending.get(key);
      if (running) return { status: 'pending', fingerprint: running.fingerprint, wait: running.wait };
      let resolve: (order: Order) => void = () => {};
      let reject: (error: unknown) => void = () => {};
      const wait = new Promise<Order>((ok, fail) => { resolve = ok; reject = fail; });
      wait.catch(() => {});
      pending.set(key, { fingerprint, wait, resolve, reject });
      return { status: 'new' };
    },
    complete(key: string, order: Order): void {
      const running = pending.get(key);
      pending.delete(key);
      if (running) {
        entries.set(key, { fingerprint: running.fingerprint, order });
        running.resolve(order);
      }
    },
    release(key: string, error?: unknown): void {
      const running = pending.get(key);
      pending.delete(key);
      if (running) running.reject(error ?? new Error('CREATE_FAILED'));
    },
    create: async (request: OrderRequest): Promise<Order> => {
      attempts++;
      await new Promise(done => setTimeout(done, options.delayMs ?? 5));
      if (options.failFirstCreate && attempts === 1) throw new Error('CREATE_FAILED');
      return { id: `ORD-${++created}`, shopId: request.shopId, items: request.items.map(item => ({ ...item })) };
    },
    count: () => created,
  };
}
