// Campaign inventory holds. Policy: Wiki > Campaign prep > Inventory holds
// reserve: hold one item for 10 minutes before payment · confirm: sell on payment success · cancel: release
export type Clock = { now(): number };
export type Audit = (event: string, orderId: string) => Promise<void>;

export class Inventory {
  private holds = new Map<string, number>(); // orderId -> expiresAt
  private sold = 0;

  private stock: number;
  private clock: Clock;
  private audit: Audit;
  private holdMs: number;

  constructor(stock: number, clock: Clock, audit: Audit = async () => {}, holdMs = 600_000) {
    this.stock = stock;
    this.clock = clock;
    this.audit = audit;
    this.holdMs = holdMs;
  }

  available(): number {
    return this.stock - this.sold - this.holds.size;
  }

  async reserve(orderId: string): Promise<boolean> {
    if (this.holds.has(orderId)) return true;
    if (this.available() <= 0) return false;
    await this.audit('reserve', orderId);
    this.holds.set(orderId, this.clock.now() + this.holdMs);
    return true;
  }

  confirm(orderId: string): boolean {
    if (!this.holds.has(orderId)) return false;
    this.holds.delete(orderId);
    this.sold += 1;
    return true;
  }

  cancel(orderId: string): boolean {
    return this.holds.delete(orderId);
  }
}
