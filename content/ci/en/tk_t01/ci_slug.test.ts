import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/tickets/slug.ts';

test('[CI] symbols are dropped', () => {
  assert.equal(slugify('Tea & Cup!'), 'tea-cup');
});

test('[CI] Korean product names', () => {
  assert.equal(slugify('벚꽃 녹차'), '벚꽃-녹차');
});
