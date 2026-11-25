// ATLAS stage 1: write to the old store and the new ledger. No cutover yet.
// Rules: Wiki > ATLAS dual write
// AICode draft: logs ledger failures and queues them. Old-store failures and duplicate retries were not validated.
export type Record = { id: string; amount: number };
export type Store = { write(r: Record): Promise<void> };
export type Result = { status: 'ok' | 'partial' | 'failed'; retry: string[] };

export async function writeBoth(r: Record, old: Store, ledger: Store, retry: string[]): Promise<Result> {
  await old.write(r);
  try {
    await ledger.write(r);
  } catch (error) {
    console.error('ledger write failed', r.id, error);
    retry.push(r.id);
    return { status: 'partial', retry };
  }
  return { status: 'ok', retry };
}
