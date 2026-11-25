import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stockBadge } from '../src/tickets/stock_badge.ts';

test('[CI] boundary: 4 is low, 5 is in_stock', () => {
  assert.equal(stockBadge(4), 'low'); assert.equal(stockBadge(5), 'in_stock');
});

test('[CI] negative stock (oversold) is sold out too', () => {
  assert.equal(stockBadge(-2), 'sold_out');
});
