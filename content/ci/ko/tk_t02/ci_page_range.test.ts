import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageRange } from '../src/tickets/page_range.ts';

test('[CI] 범위를 넘은 페이지는 null', () => {
  assert.equal(pageRange(4, 10, 25), null);
});

test('[CI] 결과가 0건이면 null', () => {
  assert.equal(pageRange(1, 10, 0), null);
});
