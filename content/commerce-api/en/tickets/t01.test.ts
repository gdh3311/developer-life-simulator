import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/tickets/slug.ts';

test('a single word is just lower case', () => {
  assert.equal(slugify('Tea'), 'tea');
});

test('several words and spaces', () => {
  assert.equal(slugify('  Spring  Tea Set '), 'spring-tea-set');
});
