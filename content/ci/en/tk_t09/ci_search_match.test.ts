import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matches } from '../src/tickets/search_match.ts';

test('[CI] word order doesn\'t matter', () => {
  assert.equal(matches('set green', 'Green Tea Set'), true);
});

test('[CI] a blank query matches nothing', () => {
  assert.equal(matches('   ', 'Green Tea'), false);
});
