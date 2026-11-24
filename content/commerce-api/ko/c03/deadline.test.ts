import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isOpen, deadlineUtc } from '../src/preorder/deadline.ts';

const kst = { local: '2026-03-10T23:00', offsetMinutes: 540 }; // 23:00 KST = 14:00 UTC
const at = (iso: string) => Date.parse(iso);

test('판매자 시각 23:00 KST는 UTC 14:00이다', () => {
  assert.equal(deadlineUtc(kst), at('2026-03-10T14:00:00Z'));
});

test('마감 1분 전에는 주문할 수 있다', () => {
  assert.equal(isOpen(kst, at('2026-03-10T13:59:00Z')), true);
});

test('마감 1분 뒤에는 주문할 수 없다', () => {
  assert.equal(isOpen(kst, at('2026-03-10T14:01:00Z')), false);
});

test('UTC 판매자도 같은 규칙이다', () => {
  const utc = { local: '2026-03-10T09:00', offsetMinutes: 0 };
  assert.equal(isOpen(utc, at('2026-03-10T08:59:00Z')), true);
  assert.equal(isOpen(utc, at('2026-03-10T09:30:00Z')), false);
});
