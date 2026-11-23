// {{ST_INTRO}}
export type OrderResponse =
  | { kind: 'created'; orderId: string }
  | { kind: 'existing'; orderId: string }
  | { kind: 'conflict' }
  | { kind: 'timeout' }
  | { kind: 'error'; code: string };

export type Screen = {
  state: 'confirmed' | 'checking' | 'review' | 'failed';
  orderId?: string;
  canRetry: boolean;
  keepKey: boolean;
};

export function screenFor(response: OrderResponse): Screen {
  switch (response.kind) {
    case 'created':
    case 'existing':
      return { state: 'confirmed', orderId: response.orderId, canRetry: false, keepKey: true };
    case 'conflict':
      return { state: 'review', canRetry: true, keepKey: false };
    case 'timeout':
      return { state: 'failed', canRetry: true, keepKey: false };
    default:
      return { state: 'failed', canRetry: true, keepKey: false, code: response.code } as Screen;
  }
}
