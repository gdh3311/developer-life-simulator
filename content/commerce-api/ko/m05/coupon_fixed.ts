export type Coupon =
  | { type: 'percent'; value: number }  // value: 0~100 (%)
  | { type: 'amount'; value: number };  // value: 원

/**
 * 주문 금액에 쿠폰을 적용한 결제 금액을 반환한다.
 * 정책: Company Wiki > "쿠폰 정책"
 */
export function applyCoupon(total: number, coupon: Coupon): number {
  const discount = coupon.type === 'percent'
    ? Math.floor(total * (coupon.value / 100))
    : coupon.value;
  return Math.max(0, total - discount);
}
