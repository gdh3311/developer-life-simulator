// Shipping fee: 3,000 won base (up to 2 kg), then 500 won per extra kg.
// Policy (Wiki 'Shipping fees'): a partial kg counts as a whole kg.
export function shippingFee(weightKg: number): number {
  // round partial kg up; nothing extra at 2 kg or less
  const extra = Math.max(0, Math.ceil(weightKg - 2));
  return 3000 + extra * 500;
}
