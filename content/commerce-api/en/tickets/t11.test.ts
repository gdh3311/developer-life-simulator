import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stockBadge } from '../src/tickets/stock_badge.ts';

test('plenty is in_stock', () => {
  assert.equal(stockBadge(10), 'in_stock');
});

test('zero is sold out', () => {
  assert.equal(stockBadge(0), 'sold_out');
});
