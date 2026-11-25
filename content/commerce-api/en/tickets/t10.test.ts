import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isEmail } from '../src/tickets/email.ts';

test('a plain address', () => {
  assert.equal(isEmail('me@mail.com'), true);
});

test('accepts plus addressing', () => {
  assert.equal(isEmail('me+shop@mail.com'), true);
});
