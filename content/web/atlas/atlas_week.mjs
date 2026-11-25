import { writeBoth } from './dual_write.ts';

// A week of refund records replayed through the repository's real writeBoth(), with the outages
// that actually happened: three ledger outages, one old-store outage, and one retried record.
const records = Array.from({ length: 40 }, (_, i) => ({ id: `rf-${1001 + i}`, amount: 1000 + i * 37 }));
const ledgerDown = new Set(['rf-1006', 'rf-1013', 'rf-1027']);
const oldDown = new Set(['rf-1019']);
const old = { saved: [], async write(r) { if (oldDown.has(r.id)) throw new Error('old store down'); this.saved.push(r.id); } };
const ledger = { saved: [], async write(r) { if (ledgerDown.has(r.id)) throw new Error('ledger down'); this.saved.push(r.id); } };
const retry = [];
const results = { ok: 0, partial: 0, failed: 0, crashed: 0 };
const crashed = [];
for (const r of records) {
  try {
    const res = await writeBoth(r, old, ledger, retry);
    results[res?.status] = (results[res?.status] ?? 0) + 1;
  } catch {
    results.crashed += 1;
    crashed.push(r.id);
  }
}
// The batch job re-sends rf-1006 once after a timeout.
try { await writeBoth(records[5], old, ledger, retry); } catch { /* counted above */ }
const savedOld = [...new Set(old.saved)];
const missing = savedOld.filter(id => !ledger.saved.includes(id) && !retry.includes(id));
console.log('CODIEN_ATLAS=' + JSON.stringify({
  total: records.length, results, retry, missing, crashed,
  duplicateRetry: retry.length !== new Set(retry).size,
  oldSaved: savedOld.length, ledgerSaved: new Set(ledger.saved).size,
}));
