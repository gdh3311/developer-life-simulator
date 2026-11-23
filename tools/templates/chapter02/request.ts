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

// {{SCOPE}}
export async function createOrder(request: OrderRequest, store: OrderStore): Promise<Order> {
  return store.create(request);
}
