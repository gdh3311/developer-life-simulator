// Payment webhook handling. Policy: Wiki > Campaign prep > Payment webhooks
// Each event once; late successes go to the reconciliation list for a person to check.
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
  if (ledger.processed.has(event.id)) return 'duplicate';
  ledger.processed.add(event.id);
  const order = ledger.orders.get(event.orderId);
  if (!order) {
    ledger.reconcile.push({ orderId: event.orderId, eventId: event.id, reason: 'unknown_order' });
    return 'reconcile';
  }
  if (event.type === 'succeeded') {
    if (order.status === 'paid') return 'duplicate';
    if (order.status === 'cancelled') {
      // Money arrived for an order we already cancelled: a person refunds it.
      ledger.reconcile.push({ orderId: order.id, eventId: event.id, reason: 'late_success' });
      return 'reconcile';
    }
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }
  if (order.status !== 'pending') return 'ignored'; // an older failure never downgrades a result
  order.status = 'failed';
  return 'failed';
}
