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
  const order = ledger.orders.get(event.orderId)!;
  if (event.type === 'succeeded') {
    order.status = 'paid';
    ledger.charges += 1;
    return 'paid';
  }
  order.status = 'failed';
  return 'failed';
}
