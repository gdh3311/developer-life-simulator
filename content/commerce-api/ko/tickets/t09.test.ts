import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matches } from '../src/tickets/search_match.ts';

test('그대로 들어 있으면 찾는다', () => {
  assert.equal(matches('Tea', 'Green Tea'), true);
});

test('대소문자를 가리지 않는다', () => {
  assert.equal(matches('green tea', 'Green Tea Set'), true);
});
