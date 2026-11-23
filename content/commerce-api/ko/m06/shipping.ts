export type Region = 'normal' | 'remote';

/**
 * 상품 합계(subtotal)에 대한 배송비를 계산한다.
 * 정책: Company Wiki > "배송비 정책"
 */
export function shippingFee(subtotal: number, region: Region = 'normal'): number {
  // TODO(#004): 배송비 정책 구현
  throw new Error('Not implemented');
}
