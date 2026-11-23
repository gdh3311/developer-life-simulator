export type Region = 'normal' | 'remote';

/**
 * Calculates the shipping fee for a subtotal.
 * Policy: Company Wiki > "Shipping policy"
 */
export function shippingFee(subtotal: number, region: Region = 'normal'): number {
  // TODO(#004): implement the shipping policy
  throw new Error('Not implemented');
}
