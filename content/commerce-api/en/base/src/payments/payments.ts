export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'refunded';

export function canRefund(status: PaymentStatus): boolean {
  return status === 'paid';
}
