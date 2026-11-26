import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('6 items fit one box', () => {
  assert.equal(boxCount(6), 1);
});

test('7 items need two boxes (leftovers need a box)', () => {
  assert.equal(boxCount(7), 2);
});

test('0 items need no box', () => {
  assert.equal(boxCount(0), 0);
});
