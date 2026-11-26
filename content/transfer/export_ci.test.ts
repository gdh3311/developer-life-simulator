import { test } from 'node:test';
import { deepStrictEqual } from 'node:assert/strict';
import { exportOrder } from '../src/transfer/export_orders.ts';

test('[CI] keeps seller mapping scoped and skips orders without a mapped seller', () => {
  const row = { shop: 'NX-52', id: 'ORD-104', totalWon: 7_500, refundedWon: null };
  deepStrictEqual(exportOrder(row, { 'NX-41': 'AUR-01', 'NX-52': 'AUR-02' }), {
    version: 1, sellerCode: 'AUR-02', orderId: 'ORD-104', totalWon: 7_500, refundedWon: 0,
  });
  deepStrictEqual(exportOrder(row, { 'NX-41': 'AUR-01' }), null);
});
