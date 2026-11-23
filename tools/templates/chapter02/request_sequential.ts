// {{INTRO}}
export type Item = { sku: string; price: number; quantity: number };
export type OrderRequest = { shopId: string; requestKey?: string | null; items: Item[] };
export type Order = { id: string; shopId: string; items: Item[] };
export type Entry = { fingerprint: string; order: Order };
export type OrderStore = {
  get(key: string): Entry | undefined;
  set(key: string, entry: Entry): void;
  create(request: OrderRequest): Promise<Order>;
};

// {{SEQUENTIAL}}
export async function createOrder(request: OrderRequest, store: OrderStore): Promise<Order> {
  const requestKey = (request.requestKey ?? '').trim();
  if (!requestKey) throw new Error('REQUEST_KEY_REQUIRED');
  const key = JSON.stringify([request.shopId, requestKey]);
  const fingerprint = JSON.stringify(request.items);
  const existing = store.get(key);
  if (existing) {
    if (existing.fingerprint !== fingerprint) throw new Error('REQUEST_CONFLICT');
    return existing.order;
  }
  const order = await store.create(request);
  store.set(key, { fingerprint, order });
  return order;
}
