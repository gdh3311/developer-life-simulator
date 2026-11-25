import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isEmail } from '../src/tickets/email.ts';

test('평범한 주소', () => {
  assert.equal(isEmail('me@mail.com'), true);
});

test('+ 주소도 받는다', () => {
  assert.equal(isEmail('me+shop@mail.com'), true);
});
