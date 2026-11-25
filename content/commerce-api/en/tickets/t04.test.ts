import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shipDate } from '../src/tickets/ship_date.ts';

test('Monday + 2 business days is Wednesday', () => {
  assert.equal(shipDate('2027-03-15', 2), '2027-03-17');
});

test('Friday + 1 business day is Monday', () => {
  assert.equal(shipDate('2027-03-19', 1), '2027-03-22');
});
