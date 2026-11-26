import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('[CI] 7개는 상자 두 개', () => {
  assert.equal(boxCount(7), 2);
});

test('[CI] 1개도 상자 하나, 0개는 없음', () => {
  assert.equal(boxCount(1), 1);
  assert.equal(boxCount(0), 0);
});
