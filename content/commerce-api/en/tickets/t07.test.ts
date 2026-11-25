import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff } from '../src/tickets/backoff.ts';

test('the first retry waits one second', () => {
  assert.equal(backoff(0), 1000);
});

test('the tenth retry still waits at most 30 seconds', () => {
  assert.equal(backoff(10), 30000);
});
