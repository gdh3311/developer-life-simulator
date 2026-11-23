// 달빛상점의 주문 요청 처리. 정책: Wiki > 주문 요청과 재시도
export type Item = { sku: string; price: number; quantity: number };
export type OrderRequest = { shopId: string; requestKey?: string | null; items: Item[] };
export type Order = { id: string; shopId: string; items: Item[] };
export type Entry = { fingerprint: string; order: Order };
export type OrderStore = {
  get(key: string): Entry | undefined;
  set(key: string, entry: Entry): void;
  create(request: OrderRequest): Promise<Order>;
};

// TODO: 순차 재시도 계약을 구현하세요. 동시 요청은 다음 업무에서 다룹니다.
export async function createOrder(request: OrderRequest, store: OrderStore): Promise<Order> {
  return store.create(request);
}
