import { test } from 'node:test';
import { deepStrictEqual } from 'node:assert/strict';
import { importOrders } from '../src/transfer/import_orders.ts';

test('[CI] keeps colliding order IDs separate and skips unknown sellers and versions', () => {
  const first = { version: 1, sellerCode: 'AUR-01', orderId: 'ORD-104', totalWon: 32_000, refundedWon: 2_000 };
  const second = { ...first, sellerCode: 'AUR-02', totalWon: 7_500, refundedWon: 0 };
  deepStrictEqual(importOrders([first, second, { ...first, sellerCode: 'UNMAPPED' }, { ...first, version: 2, totalWon: 1 }], {
    'AUR-01': 'BL-713', 'AUR-02': 'BL-805',
  }), [
    { accountId: 'BL-713', orderId: 'ORD-104', totalWon: 32_000, refundedWon: 2_000 },
    { accountId: 'BL-805', orderId: 'ORD-104', totalWon: 7_500, refundedWon: 0 },
  ]);
});
