import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('6개는 상자 하나', () => {
  assert.equal(boxCount(6), 1);
});

test('7개는 상자 두 개 (남는 상품도 상자 필요)', () => {
  assert.equal(boxCount(7), 2);
});

test('0개는 상자 없음', () => {
  assert.equal(boxCount(0), 0);
});
