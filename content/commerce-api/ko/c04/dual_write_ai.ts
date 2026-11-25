// ATLAS 1단계: 기존 저장소와 새 원장에 함께 기록한다. 전환은 아직 하지 않는다.
// 규칙: Wiki > ATLAS 이중 기록
// AICode 초안: 원장 실패를 기록하고 재처리 목록에 넣었습니다. 기존 저장소 실패와 중복 재처리는 검증하지 않았습니다.
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
