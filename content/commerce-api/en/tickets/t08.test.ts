import { test } from 'node:test';
import assert from 'node:assert/strict';
import { vatTotal } from '../src/tickets/vat.ts';

test('one line', () => {
  assert.equal(vatTotal([1000]), 100);
});

test('lines aren\'t rounded one by one', () => {
  assert.equal(vatTotal([15, 15, 15]), 4);
});
