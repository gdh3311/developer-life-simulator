// 포장 상자 수: 상자 하나에 상품 6개까지 담습니다. 남는 상품도 상자가 하나 더 필요합니다.
// 배송비 PR 때처럼 남는 몫은 올림입니다. 7개, 0개도 테스트에 넣었어요.
export function boxCount(items: number): number {
  return Math.ceil(items / 6);
}
