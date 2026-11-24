// Pre-order cancel requests. Rules: Wiki > Pre-order cancellation and refunds
export type Order = { paid: boolean; stage: 'placed' | 'preparing' | 'shipped' };
export type CancelResult = { state: 'cancelled' | 'refund_requested' | 'needs_review' | 'rejected'; refund: boolean };

export function requestCancel(order: Order): CancelResult {
  if (order.stage === 'shipped') return { state: 'rejected', refund: false };
  return { state: 'cancelled', refund: order.paid };
}
