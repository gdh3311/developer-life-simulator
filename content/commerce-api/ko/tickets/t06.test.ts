import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isValid } from '../src/tickets/coupon_expiry.ts';

test('전날은 유효', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-30T03:00:00Z')), true);
});

test('마지막 날 오후 3시(KST)도 유효', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T06:00:00Z')), true);
});
