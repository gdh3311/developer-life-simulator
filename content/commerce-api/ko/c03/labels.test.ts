import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingLine } from '../src/preorder/labels.ts';

test('배송 예정일은 발송 날짜로 읽혀야 한다', () => {
  const line = shippingLine('3월 20일');
  assert.match(line, /발송/);
  assert.doesNotMatch(line, /도착|수령/);
});

test('받는 시점은 따로 안내한다', () => {
  assert.match(shippingLine('3월 20일'), /받/);
});
