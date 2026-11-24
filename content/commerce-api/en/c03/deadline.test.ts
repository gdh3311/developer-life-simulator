import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isOpen, deadlineUtc } from '../src/preorder/deadline.ts';

const kst = { local: '2026-03-10T23:00', offsetMinutes: 540 }; // 23:00 KST = 14:00 UTC
const at = (iso: string) => Date.parse(iso);

test('23:00 KST in seller time is 14:00 UTC', () => {
  assert.equal(deadlineUtc(kst), at('2026-03-10T14:00:00Z'));
});

test('orders are open one minute before the deadline', () => {
  assert.equal(isOpen(kst, at('2026-03-10T13:59:00Z')), true);
});

test('orders are closed one minute after the deadline', () => {
  assert.equal(isOpen(kst, at('2026-03-10T14:01:00Z')), false);
});

test('a UTC seller follows the same rule', () => {
  const utc = { local: '2026-03-10T09:00', offsetMinutes: 0 };
  assert.equal(isOpen(utc, at('2026-03-10T08:59:00Z')), true);
  assert.equal(isOpen(utc, at('2026-03-10T09:30:00Z')), false);
});
