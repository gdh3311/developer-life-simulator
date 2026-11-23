// {{LOG_INTRO}}
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

// {{LOG_TODO}}
export function requestLog(event: RequestEvent): Record<string, unknown> {
  return { ...event };
}
