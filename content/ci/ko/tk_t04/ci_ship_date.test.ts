import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shipDate } from '../src/tickets/ship_date.ts';

test('[CI] 토요일 주문 + 1영업일은 월요일', () => {
  assert.equal(shipDate('2027-03-20', 1), '2027-03-22');
});

test('[CI] 금요일 + 3영업일은 수요일', () => {
  assert.equal(shipDate('2027-03-19', 3), '2027-03-24');
});
