import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PriceCache } from '../src/pricing/price_cache.ts';

const source = (prices: Record<string, number>) => {
  const s = { reads: 0, async get(id: string) { s.reads += 1; return prices[id]; }, async set(id: string, p: number) { prices[id] = p; }, prices };
  return s;
};
const clock = () => { let t = 0; return { now: () => t, advance: (ms: number) => { t += ms; } }; };

test('화면 가격은 캐시에서 읽는다', async () => {
  const src = source({ tea: 12900 });
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  await cache.display('tea');
  assert.equal(src.reads, 1);
});

test('가격을 바꾸면 바로 새 가격이 보인다', async () => {
  const cache = new PriceCache(source({ tea: 12900 }), clock());
  await cache.display('tea');
  await cache.update('tea', 11900);
  assert.equal(await cache.display('tea'), 11900);
});

test('결제 금액은 캐시가 아니라 원본 가격이다', async () => {
  const src = source({ tea: 12900 });
  const cache = new PriceCache(src, clock());
  await cache.display('tea');
  src.prices.tea = 11900; // changed from the admin server, not through this cache
  assert.equal(await cache.checkoutPrice('tea'), 11900);
});
