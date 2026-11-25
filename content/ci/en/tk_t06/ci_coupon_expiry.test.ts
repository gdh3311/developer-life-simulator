import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isValid } from '../src/tickets/coupon_expiry.ts';

test('[CI] valid until 23:59 KST on the last day', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T14:59:00Z')), true);
});

test('[CI] expired from 00:00 KST the next day', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T15:00:00Z')), false);
});
