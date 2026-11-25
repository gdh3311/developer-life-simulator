// Ship-by date: N business days after the order date (weekends don't count). Dates are YYYY-MM-DD.
export function shipDate(orderDate: string, businessDays: number): string {
  const d = new Date(orderDate + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + businessDays);
  return d.toISOString().slice(0, 10);
}
