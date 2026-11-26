import { test } from 'node:test';
import { deepStrictEqual } from 'node:assert/strict';
import { exportOrder } from '../src/transfer/export_orders.ts';

test('exports the shared seller code and whole won amounts', () => {
  const wire = exportOrder({ shop: 'NX-41', id: 'ORD-104', totalWon: 32_000, refundedWon: 2_000 }, { 'NX-41': 'AUR-01' });
  deepStrictEqual(wire, { version: 1, sellerCode: 'AUR-01', orderId: 'ORD-104', totalWon: 32_000, refundedWon: 2_000 });
});

test('exports a historical order without a refund as zero', () => {
  const wire = exportOrder({ shop: 'NX-41', id: 'ORD-106', totalWon: 12_000 }, { 'NX-41': 'AUR-01' });
  deepStrictEqual(wire, { version: 1, sellerCode: 'AUR-01', orderId: 'ORD-106', totalWon: 12_000, refundedWon: 0 });
});
