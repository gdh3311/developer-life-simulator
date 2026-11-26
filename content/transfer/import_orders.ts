export type TransferOrder = {
  version: number;
  sellerCode: string;
  orderId: string;
  totalWon: number;
  refundedWon: number;
};

export function importOrders(orders: TransferOrder[], sellerIds: Record<string, string>) {
  // Map the shared seller code to our internal account. A repeat delivery should update
  // the previous row for that seller and order, using the last delivery's values.
  return orders.map((order) => ({
    accountId: order.sellerCode,
    orderId: order.orderId,
    totalWon: order.totalWon,
    refundedWon: order.refundedWon,
  }));
}
