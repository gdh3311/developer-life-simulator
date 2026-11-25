import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stockBadge } from '../src/tickets/stock_badge.ts';

test('넉넉하면 in_stock', () => {
  assert.equal(stockBadge(10), 'in_stock');
});

test('0개면 품절', () => {
  assert.equal(stockBadge(0), 'sold_out');
});
