// 디버그 로그: 재현하느라 요청 전체를 그대로 출력했다. 정책: Wiki > 로그에 남길 것
export type RequestEvent = {
  requestId: string;
  shopId: string;
  requestKey: string;
  attempt: number;
  result: 'created' | 'existing' | 'conflict' | 'error';
  durationMs: number;
  buyer: { name: string; address: string; phone: string };
  paymentToken: string;
  items: { sku: string; price: number; quantity: number }[];
};

// TODO(NXR-024): 추적에 필요한 필드만 남기세요. 구매자·결제 정보는 남기지 않습니다.
export function requestLog(event: RequestEvent): Record<string, unknown> {
  return { ...event };
}
