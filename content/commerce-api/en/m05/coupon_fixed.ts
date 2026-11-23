export type Coupon =
  | { type: 'percent'; value: number }  // value: 0-100 (%)
  | { type: 'amount'; value: number };  // value: won

/**
 * Returns the amount to charge after applying a coupon.
 * Policy: Company Wiki > "Coupon policy"
 */
export function applyCoupon(total: number, coupon: Coupon): number {
  const discount = coupon.type === 'percent'
    ? Math.floor(total * (coupon.value / 100))
    : coupon.value;
  return Math.max(0, total - discount);
}
