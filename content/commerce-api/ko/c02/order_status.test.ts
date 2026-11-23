import { test } from 'node:test';
import assert from 'node:assert/strict';
import { screenFor } from '../src/orders/order_status.ts';

test('생성된 주문은 주문 번호와 함께 확정으로 보여 준다', () => {
  assert.deepEqual(screenFor({ kind: 'created', orderId: 'ORD-1' }), { state: 'confirmed', orderId: 'ORD-1', canRetry: false, keepKey: true });
});

test('내용 충돌은 재확인 안내와 새 키', () => {
  const screen = screenFor({ kind: 'conflict' });
  assert.equal(screen.state, 'review');
  assert.equal(screen.keepKey, false);
});
