// Pre-order product wording. Tests: tests/labels.test.ts
export const LABELS = {
  shipDate: 'Arrives by',
  note: 'This is a pre-order item.',
};

export function shippingLine(dateText: string): string {
  return `${LABELS.shipDate}: ${dateText} · ${LABELS.note}`;
}
