import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requestLog } from '../src/orders/request_log.ts';

// 공개 정책의 원칙을 새 입력에 적용한다: 허용한 필드만 남긴다.
const extended = (attempt: number, result = 'error') => ({
  requestId: 'req-31', shopId: 'shop-77', requestKey: 'k-9', attempt, result, durationMs: 1204,
  buyer: { name: 'Mina Sample', address: '9 Sample-gil', phone: '010-1111-2222' },
  paymentToken: 'tok_ci_9999',
  buyerEmail: 'sample@example.test',
  cardLast4: '4242',
  notes: 'gate code 0420',
  items: [{ sku: 'Z', price: 1, quantity: 1 }],
});

test('[CI] 나중에 추가된 민감 필드도 새지 않는다', () => {
  const text = JSON.stringify(requestLog(extended(1) as any));
  for (const value of ['sample@example.test', '4242', 'gate code 0420', 'Mina Sample', '9 Sample-gil', 'tok_ci_9999']) assert.ok(!text.includes(value), value);
});
test('[CI] 실패 결과도 추적 정보가 남는다', () => {
  const text = JSON.stringify(requestLog(extended(1) as any));
  for (const value of ['req-31', 'shop-77', 'error', '1204']) assert.ok(text.includes(value), value);
});
test('[CI] 첫 시도와 세 번째 시도를 구분한다', () => {
  assert.notEqual(JSON.stringify(requestLog(extended(1) as any)), JSON.stringify(requestLog(extended(3) as any)));
});
