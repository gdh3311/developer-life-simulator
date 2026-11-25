// 결제 웹훅 처리. 정책: Wiki > 캠페인 준비 > 결제 웹훅
// 같은 이벤트는 한 번만, 늦게 온 성공은 사람이 확인할 조정 목록으로.
// AICode 초안: 이벤트 id로 중복을 막고 취소된 주문의 성공은 조정 목록에 넣었습니다. 모르는 주문과 조정 목록 중복은 검증하지 않았습니다.
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
  const order = ledger.orders.get(event.orderId);
  if (!order) return 'ignored';
  if (event.type === 'succeeded') {
    if (order.status === 'cancelled') {
      ledger.reconcile.push({ orderId: order.id, eventId: event.id, reason: 'late_success' });
      return 'reconcile';
    }
    if (ledger.processed.has(event.id)) return 'duplicate';
    ledger.processed.add(event.id);
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }
  if (order.status !== 'pending') return 'ignored';
  order.status = 'failed';
  return 'failed';
}
