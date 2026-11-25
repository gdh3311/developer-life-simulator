// VAT on an order: 10% of the order total, rounded down once (finance policy).
export function vatTotal(lines: number[]): number {
  const total = lines.reduce((sum, amount) => sum + amount, 0);
  return Math.floor((total * 10) / 100);
}
