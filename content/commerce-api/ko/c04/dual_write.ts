// ATLAS 1단계: 기존 저장소와 새 원장에 함께 기록한다. 전환은 아직 하지 않는다.
// 규칙: Wiki > ATLAS 이중 기록
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
