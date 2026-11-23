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

// {{LOG_ALLOW}}
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
