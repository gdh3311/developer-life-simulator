import { test } from 'node:test';
import assert from 'node:assert/strict';
import { maskPhone } from '../src/tickets/mask_phone.ts';

test('[CI] numbers without dashes', () => {
  assert.equal(maskPhone('01012345678'), '010-****-5678');
});

test('[CI] anything else is left as is', () => {
  assert.equal(maskPhone('02-555-0100'), '02-555-0100');
});
