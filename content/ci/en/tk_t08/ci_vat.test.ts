import { test } from 'node:test';
import assert from 'node:assert/strict';
import { vatTotal } from '../src/tickets/vat.ts';

test('[CI] an empty order is 0', () => {
  assert.equal(vatTotal([]), 0);
});

test('[CI] rounded down once on the total', () => {
  assert.equal(vatTotal([999, 1]), 100);
});
