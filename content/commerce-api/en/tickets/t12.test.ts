import { test } from 'node:test';
import assert from 'node:assert/strict';
import { average } from '../src/tickets/rating.ts';

test('an average', () => {
  assert.equal(average([5, 4]), 4.5);
});

test('no reviews is null', () => {
  assert.equal(average([]), null);
});
