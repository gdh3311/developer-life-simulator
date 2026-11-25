// ATLAS stage 1: write to the old store and the new ledger. No cutover yet.
// Rules: Wiki > ATLAS dual write
export type Record = { id: string; amount: number };
export type Store = { write(r: Record): Promise<void> };
export type Result = { status: 'ok' | 'partial' | 'failed'; retry: string[] };

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {
  try {
    await old.write(r);
  } catch {
    // The old store is still the source of truth: nothing was saved.
    return { status: 'failed', retry };
  }
  try {
    await ledger.write(r);
  } catch {
    // Never lose a comparison record: queue it for reprocessing (once).
    if (!retry.includes(r.id)) retry.push(r.id);
    return { status: 'partial', retry };
  }
  return { status: 'ok', retry };
}
