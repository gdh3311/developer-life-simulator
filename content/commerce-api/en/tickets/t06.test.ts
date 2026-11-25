import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isValid } from '../src/tickets/coupon_expiry.ts';

test('the day before is valid', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-30T03:00:00Z')), true);
});

test('3 p.m. KST on the last day is valid', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T06:00:00Z')), true);
});
