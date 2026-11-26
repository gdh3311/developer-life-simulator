import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('[CI] 7 items need two boxes', () => {
  assert.equal(boxCount(7), 2);
});

test('[CI] 1 item needs a box, 0 items none', () => {
  assert.equal(boxCount(1), 1);
  assert.equal(boxCount(0), 0);
});
