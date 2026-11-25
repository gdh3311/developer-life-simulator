import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeBoth } from '../src/atlas/dual_write.ts';

const ok = () => { const saved: string[] = []; return { saved, write: async (r: any) => { saved.push(r.id); } }; };
const broken = () => ({ write: async () => { throw new Error('down'); } });

test('[CI] 기존 저장소가 실패하면 원장에도 쓰지 않고 failed', async () => {
  const ledger = ok();
  const r = await writeBoth({ id: 'ord-9', amount: 100 }, broken(), ledger, []);
  assert.equal(r.status, 'failed');
  assert.deepEqual(ledger.saved, []);
});

test('[CI] 같은 기록은 재처리 목록에 한 번만', async () => {
  const retry: string[] = [];
  await writeBoth({ id: 'ord-7', amount: 100 }, ok(), broken(), retry);
  await writeBoth({ id: 'ord-7', amount: 100 }, ok(), broken(), retry);
  assert.deepEqual(retry, ['ord-7']);
});

test('[CI] 저장 자체가 실패한 기록은 재처리 대상이 아니다', async () => {
  const r = await writeBoth({ id: 'ord-8', amount: 100 }, broken(), broken(), []);
  assert.deepEqual(r.retry, []);
});
