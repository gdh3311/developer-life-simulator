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

// 허용 목록: 새 필드가 생겨도 자동으로 새어 나가지 않는다.
export function requestLog(event: RequestEvent): Record<string, unknown> {
  return {
    requestId: event.requestId,
    shopId: event.shopId,
    result: event.result,
    attempt: event.attempt,
    retried: event.attempt > 1,
    durationMs: event.durationMs,
  };
}
