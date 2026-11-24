// 예약 판매 마감. 판매자는 자기 현지 시각으로 마감을 적고, 서버는 UTC 밀리초로 비교한다.
// 규칙: Wiki > 예약 판매 마감 시각
export type Deadline = { local: string; offsetMinutes: number }; // local: 'YYYY-MM-DDTHH:mm', offset: seller UTC offset (KST = 540)

export function deadlineUtc(d: Deadline): number {
  // Seller local wall-clock time minus the seller's offset gives the UTC instant.
  return Date.parse(d.local + ':00Z') - d.offsetMinutes * 60_000;
}

export function isOpen(d: Deadline, nowUtcMs: number): boolean {
  // The deadline minute itself is already closed.
  return nowUtcMs < deadlineUtc(d);
}
