// A coupon is valid through the whole 'until' day in Korean time (KST, UTC+9).
export function isValid(until: string, nowMs: number): boolean {
  return nowMs < Date.parse(until + 'T00:00:00Z');
}
