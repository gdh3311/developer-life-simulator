export type Order = { total: number; legacy?: boolean };

export function refundAmount(order: Order, ratio: number): number {
  return Math.round(order.total * ratio);
}
