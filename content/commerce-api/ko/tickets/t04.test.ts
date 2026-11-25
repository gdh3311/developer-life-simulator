import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shipDate } from '../src/tickets/ship_date.ts';

test('월요일 + 2영업일은 수요일', () => {
  assert.equal(shipDate('2027-03-15', 2), '2027-03-17');
});

test('금요일 + 1영업일은 월요일', () => {
  assert.equal(shipDate('2027-03-19', 1), '2027-03-22');
});
