import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matches } from '../src/tickets/search_match.ts';

test('finds an exact substring', () => {
  assert.equal(matches('Tea', 'Green Tea'), true);
});

test('ignores case', () => {
  assert.equal(matches('green tea', 'Green Tea Set'), true);
});
