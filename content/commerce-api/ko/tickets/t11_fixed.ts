// The badge on a product card: sold_out (0), low (1-4), in_stock (5+).
export function stockBadge(n: number): 'sold_out' | 'low' | 'in_stock' {
  if (n <= 0) return 'sold_out';
  if (n < 5) return 'low';
  return 'in_stock';
}
