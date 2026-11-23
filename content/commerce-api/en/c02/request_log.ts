// Debug log: dumped the whole request while reproducing. Policy: Wiki > What logs keep
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

// TODO(NXR-024): keep only the fields needed for tracing. No buyer or payment data.
export function requestLog(event: RequestEvent): Record<string, unknown> {
  return { ...event };
}
