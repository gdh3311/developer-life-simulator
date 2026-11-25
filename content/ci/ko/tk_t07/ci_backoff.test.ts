import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff } from '../src/tickets/backoff.ts';

test('[CI] 경계 바로 위에서 잘린다', () => {
  assert.equal(backoff(5), 30000);
});

test('[CI] 음수 시도는 0', () => {
  assert.equal(backoff(-1), 0);
});
