// The 20:00 spring campaign rush, replayed through the repository's own code:
// src/inventory/reserve.ts, src/pricing/price_cache.ts and src/payments/webhook.ts.
// argv[2..4] = stage (ten|all|no_coupon) limit (keep|double|off) extend (accept|reduce|decline).
// Plain words, not JSON: quotes don't survive every platform's argument passing.
const [stage = 'ten', limit = 'keep', extend = 'decline'] = process.argv.slice(2);
const plan = { stage, limit, extend };
const out = { plan, stock: 120, sold: 0, oversold: 0, duplicateCharges: 0, wrongPrice: 0, paidNoStock: 0,
  reconcile: [], minutes: [], queuePeak: 0, gaveUp: 0, soldOutAt: null, admitted: 0, paid: 0, revenue: 0,
  extra: null, errors: [], crashed: 0, gatewayErrors: 0, stuck: 0 };

let Inventory, PriceCache, handle;
try { ({ Inventory } = await import('./reserve.ts')); } catch (e) { out.errors.push('reserve: ' + String(e?.message ?? e).slice(0, 120)); }
try { ({ PriceCache } = await import('./price_cache.ts')); } catch (e) { out.errors.push('price_cache: ' + String(e?.message ?? e).slice(0, 120)); }
try { ({ handle } = await import('./webhook.ts')); } catch (e) { out.errors.push('webhook: ' + String(e?.message ?? e).slice(0, 120)); }
if (!Inventory || !PriceCache || !handle) {
  console.log('CODIEN_CAMPAIGN=' + JSON.stringify(out));
  process.exit(0);
}

// Deterministic "random" per buyer.
const roll = (id, salt) => { let h = 2166136261; for (const c of id + salt) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return ((h >>> 0) % 1000) / 1000; };

let now = Date.parse('2027-03-20T11:00:00Z'); // 20:00 KST
const clock = { now: () => now };
const prices = { tea: 12900 };
const source = { async get(id) { await null; return prices[id]; }, async set(id, p) { await null; prices[id] = p; } };
const cache = new PriceCache(source, clock);
const ledger = { orders: new Map(), processed: new Set(), reconcile: [], charges: 0 };
const paidOrders = new Set();

// Last year's first half hour per minute, times three (the sales forecast).
const LAST_YEAR = [100, 47, 31, 24, 20, 17, 15, 13, 12, 11, 10, 9, 9, 8, 8, 7, 7, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4];
const GATEWAY = 200; // payments per minute the gateway accepts
const LIMIT = { keep: 120, double: 240, off: Infinity }[plan.limit] ?? 120;

async function sell(inv, stock, minutes, label, arrivalsFor) {
  let queue = [];
  let soldOut = null;
  let n = 0;
  for (let m = 0; m < minutes; m++) {
    const arrivals = arrivalsFor(m);
    for (let i = 0; i < arrivals; i++) queue.push({ id: `${label}-${++n}`, since: m });
    const before = queue.length;
    queue = queue.filter(b => m - b.since <= 5); // waited too long and left
    out.gaveUp += before - queue.length;
    const batch = queue.splice(0, LIMIT === Infinity ? queue.length : LIMIT);
    out.queuePeak = Math.max(out.queuePeak, queue.length);
    out.admitted += batch.length;
    await cache.display('tea'); // the product page everyone is looking at
    let won = 0;
    let payments = 0;
    // Everyone in this minute presses "buy" at once.
    const holds = await Promise.all(batch.map(async b => {
      try { return [b, await inv.reserve(b.id)]; } catch { out.crashed += 1; return [b, false]; }
    }));
    for (const [idx, [b, ok]] of holds.entries()) {
      // 20:01, mid-minute: marketing corrects the campaign price.
      if (m === 1 && label === 'main' && idx === Math.floor(holds.length / 2)) await cache.update('tea', 11900);
      if (!ok) continue;
      ledger.orders.set(b.id, { id: b.id, status: 'pending' });
      const r = roll(b.id, 'fate');
      if (r < 0.80 && ++payments > GATEWAY) {
        // The payment gateway only takes so many per minute: the rest see an error page.
        out.gatewayErrors += 1;
        inv.cancel(b.id);
        ledger.orders.get(b.id).status = 'failed';
      } else if (r < 0.80) {
        const price = await cache.checkoutPrice('tea');
        if (price !== prices.tea) out.wrongPrice += 1;
        const deliveries = roll(b.id, 'dup') < 0.12 ? 2 : 1; // the gateway retries some webhooks
        for (let d = 0; d < deliveries; d++) {
          let res;
          try { res = handle({ id: 'ev-' + b.id, orderId: b.id, type: 'succeeded' }, ledger); } catch { out.crashed += 1; continue; }
          if (res === 'paid' && !paidOrders.has(b.id)) {
            paidOrders.add(b.id);
            won += price;
            if (inv.confirm(b.id)) out.sold += 1; else out.paidNoStock += 1;
          }
        }
      } else if (r < 0.92) {
        // Abandoned at the payment page: the hold has to expire on its own.
      } else {
        inv.cancel(b.id);
        ledger.orders.get(b.id).status = 'cancelled';
        if (roll(b.id, 'late') < 0.3) {
          try { handle({ id: 'ev-late-' + b.id, orderId: b.id, type: 'succeeded' }, ledger); } catch { out.crashed += 1; }
          try { handle({ id: 'ev-late-' + b.id, orderId: b.id, type: 'succeeded' }, ledger); } catch { out.crashed += 1; }
        }
      }
    }
    out.revenue += won;
    let left = 0;
    try { left = inv.available(); } catch { left = 0; }
    if (soldOut === null && left <= 0) soldOut = m;
    out.minutes.push({ label, m, arrivals, admitted: batch.length, queue: queue.length, won });
    now += 60_000;
  }
  return soldOut;
}

const inv = new Inventory(out.stock, clock, async () => { await null; });
const ten = plan.stage === 'ten';
const soldOutAt = await sell(inv, out.stock, 30, 'main', m => {
  const base = LAST_YEAR[m] * 3;
  if (!ten) return base;
  // 10% of customers get early access for ten minutes; everyone else from 20:10.
  if (m < 10) return Math.round(base * 0.1);
  if (m === 10) return Math.round(LAST_YEAR.slice(0, 10).reduce((a, b) => a + b, 0) * 3 * 0.9 * 0.5) + base;
  return base;
});
out.soldOutAt = soldOutAt === null ? null : `20:${String(soldOutAt).padStart(2, '0')}`;
// One more pass after the hold window: abandoned holds must be back on the shelf.
now += 11 * 60_000;
try { out.leftAfterHolds = inv.available(); } catch { out.leftAfterHolds = null; }
const mainSold = out.sold;
// Items nobody bought but nobody can buy either: holds that never expired.
out.stuck = Math.max(0, out.stock - mainSold - Math.max(0, out.leftAfterHolds ?? 0));

if (plan.extend !== 'decline') {
  // Moonlight's extra hour on the last day: their own leftover stock.
  const extraStock = plan.extend === 'accept' ? 40 : 20;
  const minutes = plan.extend === 'accept' ? 60 : 30;
  const extra = new Inventory(extraStock, clock, async () => { await null; });
  const soldBefore = out.sold;
  await sell(extra, extraStock, minutes, 'extra', m => (m % 3 === 0 ? 3 : 1));
  out.extra = { stock: extraStock, minutes, sold: out.sold - soldBefore };
}

out.paid = paidOrders.size;
out.duplicateCharges = Math.max(0, ledger.charges - paidOrders.size);
const totalStock = out.stock + (out.extra?.stock ?? 0);
out.oversold = Math.max(0, out.sold + out.paidNoStock - totalStock);
out.reconcile = ledger.reconcile.map(r => ({ orderId: r.orderId, reason: r.reason }));
out.reconcileDuplicates = out.reconcile.length - new Set(out.reconcile.map(r => r.orderId)).size;
console.log('CODIEN_CAMPAIGN=' + JSON.stringify(out));
