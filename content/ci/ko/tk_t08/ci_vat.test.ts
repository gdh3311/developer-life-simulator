import { test } from 'node:test';
import assert from 'node:assert/strict';
import { vatTotal } from '../src/tickets/vat.ts';

test('[CI] 빈 주문은 0', () => {
  assert.equal(vatTotal([]), 0);
});

test('[CI] 합계에서 한 번만 내림', () => {
  assert.equal(vatTotal([999, 1]), 100);
});
