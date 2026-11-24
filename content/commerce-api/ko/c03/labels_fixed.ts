// 예약 상품 화면 문구. 테스트: tests/labels.test.ts
export const LABELS = {
  shipDate: '발송 예정일',
  note: '발송 후 보통 1~2일 뒤 받으실 수 있어요.',
};

export function shippingLine(dateText: string): string {
  return `${LABELS.shipDate}: ${dateText} · ${LABELS.note}`;
}
