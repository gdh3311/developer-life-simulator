import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shipDate } from '../src/tickets/ship_date.ts';

test('[CI] a Saturday order + 1 is Monday', () => {
  assert.equal(shipDate('2027-03-20', 1), '2027-03-22');
});

test('[CI] Friday + 3 is Wednesday', () => {
  assert.equal(shipDate('2027-03-19', 3), '2027-03-24');
});
