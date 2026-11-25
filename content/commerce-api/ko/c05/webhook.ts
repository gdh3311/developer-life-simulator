// 결제 웹훅 처리. 정책: Wiki > 캠페인 준비 > 결제 웹훅
// 같은 이벤트는 한 번만, 늦게 온 성공은 사람이 확인할 조정 목록으로.
export type PaymentEvent = { id: string; orderId: string; type: 'succeeded' | 'failed' };
export type Order = { id: string; status: 'pending' | 'paid' | 'cancelled' | 'failed' };
export type Ledger = {
  orders: Map<string, Order>;
  processed: Set<string>;
  reconcile: { orderId: string; eventId: string; reason: string }[];
  charges: number;
};
export type Outcome = 'paid' | 'duplicate' | 'reconcile' | 'ignored' | 'failed';

export function handle(event: PaymentEvent, ledger: Ledger): Outcome {
  const order = ledger.orders.get(event.orderId)!;
  if (event.type === 'succeeded') {
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }
  order.status = 'failed';
  return 'failed';
}
