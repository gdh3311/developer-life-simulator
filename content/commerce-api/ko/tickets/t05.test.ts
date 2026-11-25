import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csvRow } from '../src/tickets/csv_row.ts';

test('평범한 값', () => {
  assert.equal(csvRow(['ORD-1', 'tea']), 'ORD-1,tea');
});

test('쉼표가 든 값은 따옴표로', () => {
  assert.equal(csvRow(['tea, green', '2']), '"tea, green",2');
});
