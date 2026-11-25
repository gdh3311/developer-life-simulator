import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csvRow } from '../src/tickets/csv_row.ts';

test('[CI] 따옴표는 두 번 쓴다', () => {
  assert.equal(csvRow(['say "hi"']), '"say ""hi"""');
});

test('[CI] 줄바꿈이 든 값', () => {
  assert.equal(csvRow(['a\nb']), '"a\nb"');
});
