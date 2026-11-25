import { test } from 'node:test';
import assert from 'node:assert/strict';
import { average } from '../src/tickets/rating.ts';

test('[CI] 소수 첫째 자리', () => {
  assert.equal(average([5, 4, 4]), 4.3);
});

test('[CI] 1~5 밖의 값은 무시', () => {
  assert.equal(average([5, 0, 6, 4]), 4.5);
});
