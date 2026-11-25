// A coupon is valid through the whole 'until' day in Korean time (KST, UTC+9).
export function isValid(until: string, nowMs: number): boolean {
  const endKst = Date.parse(until + 'T00:00:00Z') + 24 * 3600_000 - 9 * 3600_000;
  return nowMs < endKst;
}
