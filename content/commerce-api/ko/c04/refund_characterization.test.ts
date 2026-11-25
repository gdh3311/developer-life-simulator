import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundAmount } from '../src/refunds/refund.ts';

// 특성 테스트: 지금 코드가 실제로 하는 일을 그대로 고정한다. 옳고 그름은 나중에 판단한다.
test('일반 주문 절반 환불', () => {
  assert.equal(refundAmount({ total: 12000 }, 0.5), 6000);
});

// TODO: legacy 주문의 동작도 고정하세요. 분기를 지우면 이 파일이 실패해야 합니다.
