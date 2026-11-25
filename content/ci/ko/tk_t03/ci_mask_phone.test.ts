import { test } from 'node:test';
import assert from 'node:assert/strict';
import { maskPhone } from '../src/tickets/mask_phone.ts';

test('[CI] 하이픈 없는 번호', () => {
  assert.equal(maskPhone('01012345678'), '010-****-5678');
});

test('[CI] 휴대폰 번호가 아니면 그대로', () => {
  assert.equal(maskPhone('02-555-0100'), '02-555-0100');
});
