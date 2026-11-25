import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isValid } from '../src/tickets/coupon_expiry.ts';

test('[CI] 마지막 날 23:59 KST까지 유효', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T14:59:00Z')), true);
});

test('[CI] 다음 날 00:00 KST부터 만료', () => {
  assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T15:00:00Z')), false);
});
