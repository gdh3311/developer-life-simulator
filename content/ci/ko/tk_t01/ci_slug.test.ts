import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/tickets/slug.ts';

test('[CI] 기호는 지운다', () => {
  assert.equal(slugify('Tea & Cup!'), 'tea-cup');
});

test('[CI] 한글 상품명', () => {
  assert.equal(slugify('벚꽃 녹차'), '벚꽃-녹차');
});
