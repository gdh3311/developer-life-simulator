import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingLine } from '../src/preorder/labels.ts';

test('the date reads as a ship date', () => {
  const line = shippingLine('Mar 20');
  assert.match(line, /Ships/);
  assert.doesNotMatch(line, /Arrive|Receive/i);
});

test('delivery timing is explained separately', () => {
  assert.match(shippingLine('Mar 20'), /[Dd]elivery/);
});
