extends RefCounted
## Player-written solutions used only by the isolated integration replay.

const NAME := """export type User = { firstName?: string | null; lastName?: string | null; nickname?: string | null };
export function getDisplayName(user: User): string {
  const parts = [user.firstName, user.lastName].map(p => (p ?? '').trim()).filter(Boolean);
  return parts.join(' ') || 'Unknown User';
}
"""
const NICKNAME := """export type User = { firstName?: string | null; lastName?: string | null; nickname?: string | null };
export function getDisplayName(user: User): string {
  const nickname = (user.nickname ?? '').trim();
  if (nickname) return nickname;
  const parts = [user.firstName, user.lastName].map(p => (p ?? '').trim()).filter(Boolean);
  return parts.join(' ') || 'Unknown User';
}
"""
const NAME_TEST := """import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getDisplayName } from '../src/users/displayName.ts';
test('player regression: whitespace-only parts fall back', () => {
  assert.equal(getDisplayName({ firstName: '\\t', lastName: null }), 'Unknown User');
  assert.equal(getDisplayName({ firstName: ' Mina ', lastName: '' }), 'Mina');
});
"""
const SHIPPING := """export function shippingFee(total: number, region = 'normal'): number {
  if (total <= 0) return 0;
  return (total >= 50000 ? 0 : 3000) + (region === 'remote' ? 5000 : 0);
}
"""
const ORDERS_BEFORE_MERGE := """import { shippingFee } from './shipping.ts';
export type OrderItem = { sku: string; price: number; quantity: number };
export function orderTotal(items: OrderItem[], region = 'normal'): number {
  const value = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  return Math.round(value + shippingFee(value, region));
}
"""
const ORDERS_RESOLVED := """import { shippingFee } from './shipping.ts';
export type OrderItem = { sku: string; price: number; quantity: number };
export function subtotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
export function orderTotal(items: OrderItem[], region = 'normal'): number {
  const value = subtotal(items);
  return Math.round(value + shippingFee(value, region));
}
"""
const SHIPPING_TEST := """import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shippingFee } from '../src/orders/shipping.ts';
test('shipping boundary 49,999', () => { assert.equal(shippingFee(49999), 3000); });
test('shipping boundary 50,000', () => { assert.equal(shippingFee(50000), 0); });
test('remote fees and empty orders', () => {
  assert.equal(shippingFee(60000, 'remote'), 5000);
  assert.equal(shippingFee(10000, 'remote'), 8000);
  assert.equal(shippingFee(0, 'remote'), 0);
});
"""
const LOGIN := """export type Session = { userId: string; token: string; expiresAt: number };
export async function login(authenticate: () => Promise<string | null>, userId: string, timeoutMs = 5000): Promise<Session> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const token = await Promise.race([
      authenticate(),
      new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('AUTH_TIMEOUT')), timeoutMs); }),
    ]);
    if (!token) throw new Error('AUTH_FAILED');
    return { userId, token, expiresAt: Date.now() + 3600000 };
  } finally {
    clearTimeout(timer);
  }
}
"""
const LOGIN_TEST := """import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/auth/login.ts';
test('player regression: timeout, missing token, provider failure', async () => {
  await assert.rejects(login(() => new Promise(() => {}), 'u', 10), {message: 'AUTH_TIMEOUT'});
  await assert.rejects(login(async () => null, 'u', 10), {message: 'AUTH_FAILED'});
  await assert.rejects(login(async () => { throw new Error('IDP_DOWN'); }, 'u', 10), {message: 'IDP_DOWN'});
});
"""
