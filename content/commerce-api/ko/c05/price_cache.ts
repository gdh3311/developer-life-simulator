// 상품 가격 캐시. 정책: Wiki > 캠페인 준비 > 가격 캐시
// display: 목록·상세 화면용(캐시) · checkoutPrice: 결제 금액(항상 원본) · update: 가격 변경
export type Clock = { now(): number };
export type PriceSource = { get(id: string): Promise<number>; set(id: string, price: number): Promise<void> };

export class PriceCache {
  private cache = new Map<string, { price: number; at: number }>();

  private source: PriceSource;
  private clock: Clock;
  private ttlMs: number;

  constructor(source: PriceSource, clock: Clock, ttlMs = 60_000) {
    this.source = source;
    this.clock = clock;
    this.ttlMs = ttlMs;
  }

  async display(id: string): Promise<number> {
    const hit = this.cache.get(id);
    if (hit && this.clock.now() - hit.at < this.ttlMs) return hit.price;
    const price = await this.source.get(id);
    this.cache.set(id, { price, at: this.clock.now() });
    return price;
  }

  async update(id: string, price: number): Promise<void> {
    await this.source.set(id, price);
  }

  async checkoutPrice(id: string): Promise<number> {
    return this.display(id);
  }
}
