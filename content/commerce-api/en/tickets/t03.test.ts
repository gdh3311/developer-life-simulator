import { test } from 'node:test';
import assert from 'node:assert/strict';
import { maskPhone } from '../src/tickets/mask_phone.ts';

test('masks the middle', () => {
  assert.equal(maskPhone('010-1234-5678'), '010-****-5678');
});
