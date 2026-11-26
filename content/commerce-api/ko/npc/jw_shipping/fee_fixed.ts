// 배송비: 기본 3,000원(2kg까지). 2kg을 넘으면 1kg마다 500원.
// 정책(위키 '배송비'): 1kg에 못 미치는 무게도 1kg으로 계산합니다.
export function shippingFee(weightKg: number): number {
  // 모자란 무게는 올림, 2kg 이하는 추가 요금 없음
  const extra = Math.max(0, Math.ceil(weightKg - 2));
  return 3000 + extra * 500;
}
