import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matches } from '../src/tickets/search_match.ts';

test('[CI] 단어 순서가 달라도 찾는다', () => {
  assert.equal(matches('set green', 'Green Tea Set'), true);
});

test('[CI] 공백만 있는 검색어는 아무것도 찾지 않는다', () => {
  assert.equal(matches('   ', 'Green Tea'), false);
});
