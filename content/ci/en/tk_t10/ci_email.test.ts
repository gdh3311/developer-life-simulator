import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isEmail } from '../src/tickets/email.ts';

test('[CI] subdomains', () => {
  assert.equal(isEmail('x@mail.co.kr'), true);
});

test('[CI] a domain without a dot is rejected', () => {
  assert.equal(isEmail('a@b'), false);
});
