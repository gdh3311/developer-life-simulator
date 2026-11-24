// Pre-order deadline. Sellers write the deadline in their local time; the server compares UTC milliseconds.
// Rules: Wiki > Pre-order deadlines
// AICode draft: fixed the seller time-zone conversion. The exact-deadline boundary was not validated.
export type Deadline = { local: string; offsetMinutes: number }; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {
  return Date.parse(d.local + ':00Z') - d.offsetMinutes * 60_000;
}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {
  return nowUtcMs <= deadlineUtc(d);
}
