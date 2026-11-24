import { createPage, formatPrice, countdownLabel, canReserve } from './compile_input.ts';

// Evaluates the page source at build time so the released page needs no runtime code.
const IMAGES = ['tea', 'cup', 'cookie', 'candle', 'jam'];
const THEMES = ['night', 'dawn', 'paper'];
const text = (v, min, max) => typeof v === 'string' && v.trim().length >= min && v.length <= max;

try {
  const page = createPage();
  if (!page || typeof page !== 'object') throw new Error('createPage must return an object');
  if (!text(page.title, 1, 40) || !text(page.headline, 1, 80) || !text(page.sub ?? '', 0, 160) || !text(page.cta, 1, 20)) {
    throw new Error('title, headline and cta need short text (sub is optional)');
  }
  if (!THEMES.includes(page.theme)) throw new Error('theme must be night, dawn or paper');
  const d = page.deadline;
  if (!d || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(d.local ?? '') || !Number.isInteger(d.offsetMinutes)) {
    throw new Error("deadline needs local 'YYYY-MM-DDTHH:mm' and an integer offsetMinutes");
  }
  if (!Array.isArray(page.products) || page.products.length < 1 || page.products.length > 6) {
    throw new Error('Use 1–6 products');
  }
  for (const p of page.products) {
    if (!text(p.name, 1, 30) || !Number.isInteger(p.price) || p.price < 0 || p.price > 10_000_000 ||
        !Number.isInteger(p.stock) || p.stock < 0 || p.stock > 999 || !IMAGES.includes(p.image) || typeof p.alt !== 'string' || p.alt.length > 80) {
      throw new Error('Each product needs name, integer price (0–10,000,000), stock (0–999), a known image and alt text');
    }
  }
  const prices = {};
  for (const won of [0, 500, 12000, 1234567, ...page.products.map(p => p.price)]) {
    const value = formatPrice(won);
    if (typeof value !== 'string') throw new Error('formatPrice must return a string');
    prices[won] = value;
  }
  const labels = {};
  for (let m = -5; m <= 1500; m++) {
    const value = countdownLabel(m);
    if (typeof value !== 'string' || value.length > 40) throw new Error('countdownLabel must return short text');
    labels[m] = value;
  }
  const reserve = {};
  for (const stock of [0, 1, 5]) {
    for (const minutes of [-1, 0, 1, 60]) {
      const value = canReserve(stock, minutes);
      if (typeof value !== 'boolean') throw new Error('canReserve must return true or false');
      reserve[`${stock}:${minutes}`] = value;
    }
  }
  console.log('CODIEN_PAGE=' + JSON.stringify({ page, prices, labels, reserve }));
} catch (error) {
  console.error(String(error?.message ?? error));
  process.exitCode = 1;
}
