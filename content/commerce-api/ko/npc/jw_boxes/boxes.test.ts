import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('6개는 상자 하나', () => {
  assert.equal(boxCount(6), 1);
});

test('12개는 상자 두 개', () => {
  assert.equal(boxCount(12), 2);
});
