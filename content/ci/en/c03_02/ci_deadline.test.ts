import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isOpen, deadlineUtc } from '../src/preorder/deadline.ts';

const at = (iso: string) => Date.parse(iso);

test('[CI] the exact deadline minute is already closed', () => {
  const kst = { local: '2026-03-10T23:00', offsetMinutes: 540 };
  assert.equal(isOpen(kst, at('2026-03-10T14:00:00Z')), false);
});

test('[CI] time zones behind UTC (negative offset)', () => {
  const ny = { local: '2026-03-10T20:00', offsetMinutes: -300 }; // 20:00 UTC-5 = 01:00 UTC next day
  assert.equal(deadlineUtc(ny), at('2026-03-11T01:00:00Z'));
  assert.equal(isOpen(ny, at('2026-03-11T00:30:00Z')), true);
});

test('[CI] a deadline after local midnight is the previous UTC day', () => {
  const kst = { local: '2026-03-11T00:30', offsetMinutes: 540 }; // 00:30 KST = 15:30 UTC the previous day
  assert.equal(deadlineUtc(kst), at('2026-03-10T15:30:00Z'));
});

test('[CI] half-hour offsets', () => {
  const ist = { local: '2026-03-10T18:00', offsetMinutes: 330 };
  assert.equal(isOpen(ist, at('2026-03-10T12:29:00Z')), true);
  assert.equal(isOpen(ist, at('2026-03-10T12:30:00Z')), false);
});
