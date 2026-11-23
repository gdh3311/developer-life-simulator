import type { OrderRequest, Entry, OrderStore } from '../src/orders/request.ts';

export function memoryStore(): OrderStore & { count(): number } {
  const entries = new Map<string, Entry>();
  let created = 0;
  return {
    get: key => entries.get(key),
    set: (key, entry) => { entries.set(key, entry); },
    create: async (request: OrderRequest) => ({
      id: `ORD-${++created}`,
      shopId: request.shopId,
      items: request.items.map(item => ({ ...item })),
    }),
    count: () => created,
  };
}
