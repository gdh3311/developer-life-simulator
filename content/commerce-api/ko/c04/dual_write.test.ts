import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeBoth } from '../src/atlas/dual_write.ts';

const ok = () => { const saved: string[] = []; return { saved, write: async (r: any) => { saved.push(r.id); } }; };
const broken = () => ({ write: async () => { throw new Error('down'); } });

test('둘 다 성공하면 ok', async () => {
  const old = ok(), ledger = ok();
  const r = await writeBoth({ id: 'ord-1', amount: 100 }, old, ledger, []);
  assert.equal(r.status, 'ok');
  assert.deepEqual(old.saved, ['ord-1']);
  assert.deepEqual(ledger.saved, ['ord-1']);
});

test('원장 실패는 partial이고 재처리 목록에 남는다', async () => {
  const r = await writeBoth({ id: 'ord-2', amount: 100 }, ok(), broken(), []);
  assert.equal(r.status, 'partial');
  assert.deepEqual(r.retry, ['ord-2']);
});

test('재처리 목록은 기존 항목을 유지한다', async () => {
  const retry = ['ord-0'];
  const r = await writeBoth({ id: 'ord-3', amount: 100 }, ok(), broken(), retry);
  assert.deepEqual(r.retry, ['ord-0', 'ord-3']);
});

test('성공하면 재처리 목록에 넣지 않는다', async () => {
  const r = await writeBoth({ id: 'ord-4', amount: 100 }, ok(), ok(), []);
  assert.deepEqual(r.retry, []);
});
