import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PriceCache } from '../src/pricing/price_cache.ts';

const source = (prices: Record<string, number>) => {
  const s = { reads: 0, async get(id: string) { s.reads += 1; return prices[id]; }, async set(id: string, p: number) { prices[id] = p; }, prices };
  return s;
};
const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('display prices come from the cache', async () => {
  const src = source({ tea: 12900 });
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  await cache.display('tea');
  assert.equal(src.reads, 1);
});

test('a price change shows up immediately', async () => {
  const cache = new PriceCache(source({ tea: 12900 }), clock());
  await cache.display('tea');
  await cache.update('tea', 11900);
  assert.equal(await cache.display('tea'), 11900);
});

test('the charged amount is the source price, not the cache', async () => {
  const src = source({ tea: 12900 });
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  src.prices.tea = 11900; // changed from the admin server, not through this cache
  assert.equal(await cache.checkoutPrice('tea'), 11900);
});
