// 예약 주문 취소 요청. 규칙: Wiki > 예약 주문 취소와 환불
export type Order = { paid: boolean; stage: 'placed' | 'preparing' | 'shipped' };
export type CancelResult = { state: 'cancelled' | 'refund_requested' | 'needs_review' | 'rejected'; refund: boolean };

export function requestCancel(order: Order): CancelResult {
  if (order.stage === 'shipped') return { state: 'rejected', refund: false };
  return { state: 'cancelled', refund: order.paid };
}
