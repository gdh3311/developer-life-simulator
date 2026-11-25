import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageRange } from '../src/tickets/page_range.ts';

test('[CI] a page past the end is null', () => {
  assert.equal(pageRange(4, 10, 25), null);
});

test('[CI] no results is null', () => {
  assert.equal(pageRange(1, 10, 0), null);
});
