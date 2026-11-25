import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isEmail } from '../src/tickets/email.ts';

test('[CI] 하위 도메인', () => {
  assert.equal(isEmail('x@mail.co.kr'), true);
});

test('[CI] 점 없는 도메인은 거절', () => {
  assert.equal(isEmail('a@b'), false);
});
