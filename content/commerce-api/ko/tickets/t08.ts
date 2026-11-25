// VAT on an order: 10% of the order total, rounded down once (finance policy).
export function vatTotal(lines: number[]): number {
  return lines.reduce((sum, amount) => sum + Math.round(amount * 0.1), 0);
}
