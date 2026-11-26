import { test } from 'node:test';
import { deepStrictEqual } from 'node:assert/strict';
import { importOrders } from '../src/transfer/import_orders.ts';

test('maps the seller and applies a repeated delivery once, keeping the latest values', () => {
  const first = { version: 1, sellerCode: 'AUR-01', orderId: 'ORD-104', totalWon: 32_000, refundedWon: 0 };
  deepStrictEqual(importOrders([first, { ...first, refundedWon: 2_000 }], { 'AUR-01': 'BL-713' }), [
    { accountId: 'BL-713', orderId: 'ORD-104', totalWon: 32_000, refundedWon: 2_000 },
  ]);
});
