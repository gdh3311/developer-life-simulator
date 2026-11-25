import { test } from 'node:test';
import assert from 'node:assert/strict';
import { vatTotal } from '../src/tickets/vat.ts';

test('한 줄', () => {
  assert.equal(vatTotal([1000]), 100);
});

test('줄마다 반올림하지 않는다', () => {
  assert.equal(vatTotal([15, 15, 15]), 4);
});
