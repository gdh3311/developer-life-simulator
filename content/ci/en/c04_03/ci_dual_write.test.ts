import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeBoth } from '../src/atlas/dual_write.ts';

const ok = () => { const saved: string[] = []; return { saved, write: async (r: any) => { saved.push(r.id); } }; };
const broken = () => ({ write: async () => { throw new Error('down'); } });

test('[CI] if the old store fails, skip the ledger and report failed', async () => {
  const ledger = ok();
  const r = await writeBoth({ id: 'ord-9', amount: 100 }, broken(), ledger, []);
  assert.equal(r.status, 'failed');
  assert.deepEqual(ledger.saved, []);
});

test('[CI] a record is queued for retry only once', async () => {
  const retry: string[] = [];
  await writeBoth({ id: 'ord-7', amount: 100 }, ok(), broken(), retry);
  await writeBoth({ id: 'ord-7', amount: 100 }, ok(), broken(), retry);
  assert.deepEqual(retry, ['ord-7']);
});

test('[CI] records that were never saved are not retried', async () => {
  const r = await writeBoth({ id: 'ord-8', amount: 100 }, broken(), broken(), []);
  assert.deepEqual(r.retry, []);
});
