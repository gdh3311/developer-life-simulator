import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stockBadge } from '../src/tickets/stock_badge.ts';

test('[CI] 경계: 4는 low, 5는 in_stock', () => {
  assert.equal(stockBadge(4), 'low'); assert.equal(stockBadge(5), 'in_stock');
});

test('[CI] 음수(초과 판매)도 품절', () => {
  assert.equal(stockBadge(-2), 'sold_out');
});
