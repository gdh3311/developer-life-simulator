import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boxCount } from '../src/shipping/boxes.ts';

test('6 items fit one box', () => {
  assert.equal(boxCount(6), 1);
});

test('12 items need two boxes', () => {
  assert.equal(boxCount(12), 2);
});
