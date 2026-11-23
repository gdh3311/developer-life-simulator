// 주문 응답을 화면 상태로 바꾼다. 합의: Wiki > 주문 화면 상태
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
      // 응답을 못 받았다고 실패는 아니다. 같은 키로 결과를 확인하거나 재시도한다.
      return { state: 'checking', canRetry: true, keepKey: true };
    default:
      return { state: 'failed', canRetry: true, keepKey: false, code: response.code } as Screen;
  }
}
