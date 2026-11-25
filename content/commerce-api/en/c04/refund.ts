// Refund amount. Moved from payments-service; first written for the 2023 launch contract.
// Policy: Wiki > Refund calculation
export type Order = { total: number; legacy?: boolean };

export function refundAmount(order: Order, ratio: number): number {
  if (order.legacy) {
    // launch-contract sellers: round down to 10 won (contract §7)
    return Math.floor((order.total * ratio) / 10) * 10;
  }
  return Math.round(order.total * ratio);
}
