// {{AI_CONCURRENT}}
export type Item = { sku: string; price: number; quantity: number };
export type OrderRequest = { shopId: string; requestKey?: string | null; items: Item[] };
export type Order = { id: string; shopId: string; items: Item[] };
export type Entry = { fingerprint: string; order: Order };

export async function createOrder(request: OrderRequest, store: any): Promise<Order> {
  const requestKey = (request.requestKey ?? '').trim();
  if (!requestKey) throw new Error('REQUEST_KEY_REQUIRED');
  const key = JSON.stringify([request.shopId, requestKey]);
  const fingerprint = JSON.stringify(request.items);
  const claim = store.claim(key, fingerprint);
  if (claim.status === 'done') {
    if (claim.fingerprint !== fingerprint) throw new Error('REQUEST_CONFLICT');
    return claim.order;
  }
  if (claim.status === 'pending') return claim.wait;
  try {
    const order = await store.create(request);
    store.complete(key, order);
    return order;
  } catch (error) {
    store.release(key, error);
    throw error;
  }
}
