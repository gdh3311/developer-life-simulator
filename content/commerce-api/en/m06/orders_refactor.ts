export type OrderItem = { sku: string; price: number; quantity: number };

/** Sum of item prices */
export function subtotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

/** Order amount to charge (rounded to whole won) */
export function orderTotal(items: OrderItem[]): number {
  return Math.round(subtotal(items));
}
