import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff } from '../src/tickets/backoff.ts';

test('첫 재시도는 1초', () => {
  assert.equal(backoff(0), 1000);
});

test('열 번째 재시도도 30초를 넘지 않는다', () => {
  assert.equal(backoff(10), 30000);
});
