export type OrderItem = { sku: string; price: number; quantity: number };

export function orderTotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
