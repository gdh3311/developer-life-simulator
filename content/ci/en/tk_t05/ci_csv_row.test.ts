import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csvRow } from '../src/tickets/csv_row.ts';

test('[CI] quotes are doubled', () => {
  assert.equal(csvRow(['say "hi"']), '"say ""hi"""');
});

test('[CI] values with a newline', () => {
  assert.equal(csvRow(['a\nb']), '"a\nb"');
});
