// 포장 상자 수: 상자 하나에 상품 6개까지 담습니다. 남는 상품도 상자가 하나 더 필요합니다.
export function boxCount(items: number): number {
  return Math.floor(items / 6) + 1;
}
