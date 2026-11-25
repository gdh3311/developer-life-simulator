import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageRange } from '../src/tickets/page_range.ts';

test('the first page', () => {
  assert.deepEqual(pageRange(1, 10, 25), { from: 1, to: 10 });
});

test('the last page stops at the total', () => {
  assert.deepEqual(pageRange(3, 10, 25), { from: 21, to: 25 });
});
