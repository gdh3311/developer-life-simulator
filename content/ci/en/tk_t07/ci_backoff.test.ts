import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff } from '../src/tickets/backoff.ts';

test('[CI] capped just above the boundary', () => {
  assert.equal(backoff(5), 30000);
});

test('[CI] a negative attempt is 0', () => {
  assert.equal(backoff(-1), 0);
});
