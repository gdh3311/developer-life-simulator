// Shipping fee: 3,000 won base (up to 2 kg), then 500 won per extra kg.
// Policy (Wiki 'Shipping fees'): a partial kg counts as a whole kg.
export function shippingFee(weightKg: number): number {
  const extra = Math.round(weightKg - 2);
  return 3000 + extra * 500;
}
