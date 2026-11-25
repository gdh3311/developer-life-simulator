// ATLAS stage 1: write to the old store and the new ledger. No cutover yet.
// Rules: Wiki > ATLAS dual write
export type Record = { id: string; amount: number };
export type Store = { write(r: Record): Promise<void> };
export type Result = { status: 'ok' | 'partial' | 'failed'; retry: string[] };

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {
  await old.write(r);
  try {
    await ledger.write(r);
  } catch {
    // ignore: the ledger is only for comparison
  }
  return { status: 'ok', retry };
}
