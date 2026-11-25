// 환불 금액 계산. 2023년 첫 계약 때 만든 모듈을 payments-service에서 옮겨 왔다.
// 정책: Wiki > 환불 계산
export type Order = { total: number; legacy?: boolean };

export function refundAmount(order: Order, ratio: number): number {
  if (order.legacy) {
    // 첫 계약 판매자: 10원 단위 내림 (계약서 7조)
    return Math.floor((order.total * ratio) / 10) * 10;
  }
  return Math.round(order.total * ratio);
}
