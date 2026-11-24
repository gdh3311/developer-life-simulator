// 예약 상품 화면 문구. 테스트: tests/labels.test.ts
export const LABELS = {
  shipDate: '도착 예정일',
  note: '예약 상품입니다.',
};

export function shippingLine(dateText: string): string {
  return `${LABELS.shipDate}: ${dateText} · ${LABELS.note}`;
}
