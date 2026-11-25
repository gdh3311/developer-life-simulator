import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageRange } from '../src/tickets/page_range.ts';

test('첫 페이지', () => {
  assert.deepEqual(pageRange(1, 10, 25), { from: 1, to: 10 });
});

test('마지막 페이지는 전체 개수에서 끝난다', () => {
  assert.deepEqual(pageRange(3, 10, 25), { from: 21, to: 25 });
});
