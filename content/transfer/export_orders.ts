export type LocalOrder = {
  shop: string;
  id: string;
  totalWon: number;
  refundedWon?: number | null;
};

export function exportOrder(order: LocalOrder, sellerCodes: Record<string, string>) {
  // The consumer expects the shared seller code, not our shop's internal ID.
  // A historical order without a refund has refundedWon equal to zero on the wire.
  return {
    version: 1,
    sellerCode: order.shop,
    orderId: order.id,
    totalWon: order.totalWon,
    refundedWon: order.refundedWon,
  };
}
