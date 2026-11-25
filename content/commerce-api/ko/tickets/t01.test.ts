import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/tickets/slug.ts';

test('한 단어는 그대로 소문자', () => {
  assert.equal(slugify('Tea'), 'tea');
});

test('여러 단어와 공백', () => {
  assert.equal(slugify('  Spring  Tea Set '), 'spring-tea-set');
});
