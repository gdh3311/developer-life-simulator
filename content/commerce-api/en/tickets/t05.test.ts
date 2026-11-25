import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csvRow } from '../src/tickets/csv_row.ts';

test('plain values', () => {
  assert.equal(csvRow(['ORD-1', 'tea']), 'ORD-1,tea');
});

test('a value with a comma is quoted', () => {
  assert.equal(csvRow(['tea, green', '2']), '"tea, green",2');
});
