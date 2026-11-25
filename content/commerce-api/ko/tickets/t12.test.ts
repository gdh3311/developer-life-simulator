import { test } from 'node:test';
import assert from 'node:assert/strict';
import { average } from '../src/tickets/rating.ts';

test('평균', () => {
  assert.equal(average([5, 4]), 4.5);
});

test('리뷰가 없으면 null', () => {
  assert.equal(average([]), null);
});
