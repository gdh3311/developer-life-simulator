// Moonlight order requests. Contract: Wiki > Order requests and retries
export type Item = { sku: string; price: number; quantity: number };
export type OrderRequest = { shopId: string; requestKey?: string | null; items: Item[] };
export type Order = { id: string; shopId: string; items: Item[] };
export type Entry = { fingerprint: string; order: Order };
export type Claim =
  | { status: 'new' }
  | { status: 'pending'; fingerprint: string; wait: Promise<Order> }
  | { status: 'done'; fingerprint: string; order: Order };
export type OrderStore = {
  get(key: string): Entry | undefined;
  set(key: string, entry: Entry): void;
  claim(key: string, fingerprint: string): Claim;
  complete(key: string, order: Order): void;
  release(key: string, error?: unknown): void;
  create(request: OrderRequest): Promise<Order>;
};

export async function createOrder(request: OrderRequest, store: OrderStore): Promise<Order> {
  const requestKey = (request.requestKey ?? '').trim();
  if (!requestKey) throw new Error('REQUEST_KEY_REQUIRED');
  const key = JSON.stringify([request.shopId, requestKey]);
  const fingerprint = JSON.stringify(request.items);
  const claim = store.claim(key, fingerprint);
  if (claim.status !== 'new') {
    if (claim.fingerprint !== fingerprint) throw new Error('REQUEST_CONFLICT');
    return claim.status === 'done' ? claim.order : claim.wait;
  }
  try {
    const order = await store.create(request);
    store.complete(key, order);
    return order;
  } catch (error) {
    store.release(key, error);
    throw error;
  }
}
