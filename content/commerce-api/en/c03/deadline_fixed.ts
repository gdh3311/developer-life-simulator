// Pre-order deadline. Sellers write the deadline in their local time; the server compares UTC milliseconds.
// Rules: Wiki > Pre-order deadlines
export type Deadline = { local: string; offsetMinutes: number }; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {
  // Seller local wall-clock time minus the seller's offset gives the UTC instant.
  return Date.parse(d.local + ':00Z') - d.offsetMinutes * 60_000;
}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {
  // The deadline minute itself is already closed.
  return nowUtcMs < deadlineUtc(d);
}
