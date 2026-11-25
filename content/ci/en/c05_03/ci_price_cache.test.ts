import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PriceCache } from '../src/pricing/price_cache.ts';

const source = (prices: Record<string, number>) => {
  const s = { reads: 0, async get(id: string) { s.reads += 1; return prices[id]; }, async set(id: string, p: number) { prices[id] = p; }, prices };
  return s;
};
const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('[CI] after the TTL the source is read again', async () => {
  const src = source({ tea: 12900 });
  const c = clock();
  const cache = new PriceCache(src, c);
  await cache.display('tea');
  src.prices.tea = 11900;
  c.advance(61_000);
  assert.equal(await cache.display('tea'), 11900);
});

test('[CI] changing one price doesn\'t flush other products', async () => {
  const src = source({ tea: 12900, cup: 5000 });
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  await cache.display('cup');
  await cache.update('tea', 11900);
  const before = src.reads;
  await cache.display('cup');
  assert.equal(src.reads, before);
});
