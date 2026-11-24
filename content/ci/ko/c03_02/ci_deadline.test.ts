import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isOpen, deadlineUtc } from '../src/preorder/deadline.ts';

const at = (iso: string) => Date.parse(iso);

test('[CI] 마감 정각에는 이미 닫혀 있다', () => {
  const kst = { local: '2026-03-10T23:00', offsetMinutes: 540 };
  assert.equal(isOpen(kst, at('2026-03-10T14:00:00Z')), false);
});

test('[CI] UTC보다 늦은 시간대(음수 오프셋)', () => {
  const ny = { local: '2026-03-10T20:00', offsetMinutes: -300 }; // 20:00 UTC-5 = 01:00 UTC next day
  assert.equal(deadlineUtc(ny), at('2026-03-11T01:00:00Z'));
  assert.equal(isOpen(ny, at('2026-03-11T00:30:00Z')), true);
});

test('[CI] 현지 자정 이후 마감은 UTC로 전날이다', () => {
  const kst = { local: '2026-03-11T00:30', offsetMinutes: 540 }; // 00:30 KST = 15:30 UTC the previous day
  assert.equal(deadlineUtc(kst), at('2026-03-10T15:30:00Z'));
});

test('[CI] 30분 단위 오프셋', () => {
  const ist = { local: '2026-03-10T18:00', offsetMinutes: 330 };
  assert.equal(isOpen(ist, at('2026-03-10T12:29:00Z')), true);
  assert.equal(isOpen(ist, at('2026-03-10T12:30:00Z')), false);
});
