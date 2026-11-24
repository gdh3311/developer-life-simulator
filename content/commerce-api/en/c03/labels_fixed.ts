// Pre-order product wording. Tests: tests/labels.test.ts
export const LABELS = {
  shipDate: 'Ships by',
  note: 'Delivery usually takes 1-2 days after shipping.',
};

export function shippingLine(dateText: string): string {
  return `${LABELS.shipDate}: ${dateText} · ${LABELS.note}`;
}
