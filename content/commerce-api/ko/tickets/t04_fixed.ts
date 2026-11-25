// Ship-by date: N business days after the order date (weekends don't count). Dates are YYYY-MM-DD.
export function shipDate(orderDate: string, businessDays: number): string {
  const d = new Date(orderDate + 'T00:00:00Z');
  let left = businessDays;
  while (left > 0) {
    d.setUTCDate(d.getUTCDate() + 1);
    const day = d.getUTCDay();
    if (day !== 0 && day !== 6) left -= 1;
  }
  return d.toISOString().slice(0, 10);
}
