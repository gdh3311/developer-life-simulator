// Payment webhook handling. Policy: Wiki > Campaign prep > Payment webhooks
// Each event once; late successes go to the reconciliation list for a person to check.
// AICode draft: dedupes by event id and routes successes on cancelled orders to reconciliation. Unknown orders and duplicate reconciliation entries were not validated.
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
