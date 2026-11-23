export type OrderItem = { sku: string; price: number; quantity: number };

/** 상품 금액 합계 */
export function subtotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

/** 결제할 주문 금액 (원 단위 반올림) */
export function orderTotal(items: OrderItem[]): number {
  return Math.round(subtotal(items));
}
