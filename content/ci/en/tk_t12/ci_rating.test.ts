import { test } from 'node:test';
import assert from 'node:assert/strict';
import { average } from '../src/tickets/rating.ts';

test('[CI] one decimal', () => {
  assert.equal(average([5, 4, 4]), 4.3);
});

test('[CI] values outside 1-5 are ignored', () => {
  assert.equal(average([5, 0, 6, 4]), 4.5);
});
