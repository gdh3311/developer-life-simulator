"""Generate the side-ticket board content (small real bugs) for both languages.

Writes content/commerce-api/{ko,en}/tickets/<id>.ts, <id>_fixed.ts, <id>.test.ts and hidden CI under
content/ci/{ko,en}/tk_<id>/. Every buggy module fails at least one public test; the fixed one passes
public and hidden tests (checked by tools/check_tickets.py).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# id: (module file, buggy, fixed, public tests [(name ko, name en, body)], hidden tests [...])
TICKETS = {}


def ticket(tid, module, buggy, fixed, public, hidden):
    TICKETS[tid] = (module, buggy.strip() + "\n", fixed.strip() + "\n", public, hidden)


ticket("t01", "slug", """
// Product URL slugs. Policy: lower case, words joined by '-', no other symbols.
export function slugify(name: string): string {
  return name.toLowerCase().replace(' ', '-');
}
""", """
// Product URL slugs. Policy: lower case, words joined by '-', no other symbols.
export function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9가-힣\\s_-]/g, ' ')
    .split(/[\\s_-]+/)
    .filter(Boolean)
    .join('-');
}
""", [
    ("한 단어는 그대로 소문자", "a single word is just lower case", "assert.equal(slugify('Tea'), 'tea');"),
    ("여러 단어와 공백", "several words and spaces", "assert.equal(slugify('  Spring  Tea Set '), 'spring-tea-set');"),
], [
    ("[CI] 기호는 지운다", "[CI] symbols are dropped", "assert.equal(slugify('Tea & Cup!'), 'tea-cup');"),
    ("[CI] 한글 상품명", "[CI] Korean product names", "assert.equal(slugify('벚꽃 녹차'), '벚꽃-녹차');"),
])

ticket("t02", "page_range", """
// Which rows a page shows (1-based, inclusive). Out-of-range pages show nothing (null).
export function pageRange(page: number, size: number, total: number): { from: number; to: number } | null {
  return { from: (page - 1) * size, to: page * size };
}
""", """
// Which rows a page shows (1-based, inclusive). Out-of-range pages show nothing (null).
export function pageRange(page: number, size: number, total: number): { from: number; to: number } | null {
  const from = (page - 1) * size + 1;
  if (page < 1 || size < 1 || from > total) return null;
  return { from, to: Math.min(page * size, total) };
}
""", [
    ("첫 페이지", "the first page", "assert.deepEqual(pageRange(1, 10, 25), { from: 1, to: 10 });"),
    ("마지막 페이지는 전체 개수에서 끝난다", "the last page stops at the total", "assert.deepEqual(pageRange(3, 10, 25), { from: 21, to: 25 });"),
], [
    ("[CI] 범위를 넘은 페이지는 null", "[CI] a page past the end is null", "assert.equal(pageRange(4, 10, 25), null);"),
    ("[CI] 결과가 0건이면 null", "[CI] no results is null", "assert.equal(pageRange(1, 10, 0), null);"),
])

ticket("t03", "mask_phone", """
// Masks the middle of a Korean mobile number for receipts: 010-****-5678.
export function maskPhone(phone: string): string {
  return phone.slice(0, -4) + '****';
}
""", """
// Masks the middle of a Korean mobile number for receipts: 010-****-5678.
export function maskPhone(phone: string): string {
  const digits = phone.replace(/-/g, '');
  if (!/^01\\d{8,9}$/.test(digits)) return phone;
  return `${digits.slice(0, 3)}-****-${digits.slice(-4)}`;
}
""", [
    ("가운데를 가린다", "masks the middle", "assert.equal(maskPhone('010-1234-5678'), '010-****-5678');"),
], [
    ("[CI] 하이픈 없는 번호", "[CI] numbers without dashes", "assert.equal(maskPhone('01012345678'), '010-****-5678');"),
    ("[CI] 휴대폰 번호가 아니면 그대로", "[CI] anything else is left as is", "assert.equal(maskPhone('02-555-0100'), '02-555-0100');"),
])

ticket("t04", "ship_date", """
// Ship-by date: N business days after the order date (weekends don't count). Dates are YYYY-MM-DD.
export function shipDate(orderDate: string, businessDays: number): string {
  const d = new Date(orderDate + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + businessDays);
  return d.toISOString().slice(0, 10);
}
""", """
// Ship-by date: N business days after the order date (weekends don't count). Dates are YYYY-MM-DD.
export function shipDate(orderDate: string, businessDays: number): string {
  const d = new Date(orderDate + 'T00:00:00Z');
  let left = businessDays;
  while (left > 0) {
    d.setUTCDate(d.getUTCDate() + 1);
    const day = d.getUTCDay();
    if (day !== 0 && day !== 6) left -= 1;
  }
  return d.toISOString().slice(0, 10);
}
""", [
    ("월요일 + 2영업일은 수요일", "Monday + 2 business days is Wednesday", "assert.equal(shipDate('2027-03-15', 2), '2027-03-17');"),
    ("금요일 + 1영업일은 월요일", "Friday + 1 business day is Monday", "assert.equal(shipDate('2027-03-19', 1), '2027-03-22');"),
], [
    ("[CI] 토요일 주문 + 1영업일은 월요일", "[CI] a Saturday order + 1 is Monday", "assert.equal(shipDate('2027-03-20', 1), '2027-03-22');"),
    ("[CI] 금요일 + 3영업일은 수요일", "[CI] Friday + 3 is Wednesday", "assert.equal(shipDate('2027-03-19', 3), '2027-03-24');"),
])

ticket("t05", "csv_row", """
// One CSV line for the seller's order export.
export function csvRow(values: string[]): string {
  return values.join(',');
}
""", """
// One CSV line for the seller's order export.
export function csvRow(values: string[]): string {
  return values
    .map(v => (/[",\\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v))
    .join(',');
}
""", [
    ("평범한 값", "plain values", "assert.equal(csvRow(['ORD-1', 'tea']), 'ORD-1,tea');"),
    ("쉼표가 든 값은 따옴표로", "a value with a comma is quoted", "assert.equal(csvRow(['tea, green', '2']), '\"tea, green\",2');"),
], [
    ("[CI] 따옴표는 두 번 쓴다", "[CI] quotes are doubled", "assert.equal(csvRow(['say \"hi\"']), '\"say \"\"hi\"\"\"');"),
    ("[CI] 줄바꿈이 든 값", "[CI] values with a newline", "assert.equal(csvRow(['a\\nb']), '\"a\\nb\"');"),
])

ticket("t06", "coupon_expiry", """
// A coupon is valid through the whole 'until' day in Korean time (KST, UTC+9).
export function isValid(until: string, nowMs: number): boolean {
  return nowMs < Date.parse(until + 'T00:00:00Z');
}
""", """
// A coupon is valid through the whole 'until' day in Korean time (KST, UTC+9).
export function isValid(until: string, nowMs: number): boolean {
  const endKst = Date.parse(until + 'T00:00:00Z') + 24 * 3600_000 - 9 * 3600_000;
  return nowMs < endKst;
}
""", [
    ("전날은 유효", "the day before is valid", "assert.equal(isValid('2027-03-31', Date.parse('2027-03-30T03:00:00Z')), true);"),
    ("마지막 날 오후 3시(KST)도 유효", "3 p.m. KST on the last day is valid", "assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T06:00:00Z')), true);"),
], [
    ("[CI] 마지막 날 23:59 KST까지 유효", "[CI] valid until 23:59 KST on the last day", "assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T14:59:00Z')), true);"),
    ("[CI] 다음 날 00:00 KST부터 만료", "[CI] expired from 00:00 KST the next day", "assert.equal(isValid('2027-03-31', Date.parse('2027-03-31T15:00:00Z')), false);"),
])

ticket("t07", "backoff", """
// Retry delay for the notification sender: doubles each attempt, never more than 30 seconds.
export function backoff(attempt: number): number {
  return 1000 * 2 ** attempt;
}
""", """
// Retry delay for the notification sender: doubles each attempt, never more than 30 seconds.
export function backoff(attempt: number): number {
  if (attempt < 0) return 0;
  return Math.min(30_000, 1000 * 2 ** attempt);
}
""", [
    ("첫 재시도는 1초", "the first retry waits one second", "assert.equal(backoff(0), 1000);"),
    ("열 번째 재시도도 30초를 넘지 않는다", "the tenth retry still waits at most 30 seconds", "assert.equal(backoff(10), 30000);"),
], [
    ("[CI] 경계 바로 위에서 잘린다", "[CI] capped just above the boundary", "assert.equal(backoff(5), 30000);"),
    ("[CI] 음수 시도는 0", "[CI] a negative attempt is 0", "assert.equal(backoff(-1), 0);"),
])

ticket("t08", "vat", """
// VAT on an order: 10% of the order total, rounded down once (finance policy).
export function vatTotal(lines: number[]): number {
  return lines.reduce((sum, amount) => sum + Math.round(amount * 0.1), 0);
}
""", """
// VAT on an order: 10% of the order total, rounded down once (finance policy).
export function vatTotal(lines: number[]): number {
  const total = lines.reduce((sum, amount) => sum + amount, 0);
  return Math.floor((total * 10) / 100);
}
""", [
    ("한 줄", "one line", "assert.equal(vatTotal([1000]), 100);"),
    ("줄마다 반올림하지 않는다", "lines aren't rounded one by one", "assert.equal(vatTotal([15, 15, 15]), 4);"),
], [
    ("[CI] 빈 주문은 0", "[CI] an empty order is 0", "assert.equal(vatTotal([]), 0);"),
    ("[CI] 합계에서 한 번만 내림", "[CI] rounded down once on the total", "assert.equal(vatTotal([999, 1]), 100);"),
])

ticket("t09", "search_match", """
// Store search: every word of the query must appear in the product name, ignoring case.
export function matches(query: string, name: string): boolean {
  return name.includes(query);
}
""", """
// Store search: every word of the query must appear in the product name, ignoring case.
export function matches(query: string, name: string): boolean {
  const words = query.trim().toLowerCase().split(/\\s+/).filter(Boolean);
  const target = name.toLowerCase();
  return words.length > 0 && words.every(w => target.includes(w));
}
""", [
    ("그대로 들어 있으면 찾는다", "finds an exact substring", "assert.equal(matches('Tea', 'Green Tea'), true);"),
    ("대소문자를 가리지 않는다", "ignores case", "assert.equal(matches('green tea', 'Green Tea Set'), true);"),
], [
    ("[CI] 단어 순서가 달라도 찾는다", "[CI] word order doesn't matter", "assert.equal(matches('set green', 'Green Tea Set'), true);"),
    ("[CI] 공백만 있는 검색어는 아무것도 찾지 않는다", "[CI] a blank query matches nothing", "assert.equal(matches('   ', 'Green Tea'), false);"),
])

ticket("t10", "email", """
// Sign-up email check: one @, a dot in the domain, no spaces.
export function isEmail(s: string): boolean {
  return /^[a-z0-9.]+@[a-z0-9]+\\.[a-z]+$/.test(s);
}
""", """
// Sign-up email check: one @, a dot in the domain, no spaces.
export function isEmail(s: string): boolean {
  return /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(s);
}
""", [
    ("평범한 주소", "a plain address", "assert.equal(isEmail('me@mail.com'), true);"),
    ("+ 주소도 받는다", "accepts plus addressing", "assert.equal(isEmail('me+shop@mail.com'), true);"),
], [
    ("[CI] 하위 도메인", "[CI] subdomains", "assert.equal(isEmail('x@mail.co.kr'), true);"),
    ("[CI] 점 없는 도메인은 거절", "[CI] a domain without a dot is rejected", "assert.equal(isEmail('a@b'), false);"),
])

ticket("t11", "stock_badge", """
// The badge on a product card: sold_out (0), low (1-4), in_stock (5+).
export function stockBadge(n: number): 'sold_out' | 'low' | 'in_stock' {
  if (n < 5) return 'low';
  return 'in_stock';
}
""", """
// The badge on a product card: sold_out (0), low (1-4), in_stock (5+).
export function stockBadge(n: number): 'sold_out' | 'low' | 'in_stock' {
  if (n <= 0) return 'sold_out';
  if (n < 5) return 'low';
  return 'in_stock';
}
""", [
    ("넉넉하면 in_stock", "plenty is in_stock", "assert.equal(stockBadge(10), 'in_stock');"),
    ("0개면 품절", "zero is sold out", "assert.equal(stockBadge(0), 'sold_out');"),
], [
    ("[CI] 경계: 4는 low, 5는 in_stock", "[CI] boundary: 4 is low, 5 is in_stock", "assert.equal(stockBadge(4), 'low'); assert.equal(stockBadge(5), 'in_stock');"),
    ("[CI] 음수(초과 판매)도 품절", "[CI] negative stock (oversold) is sold out too", "assert.equal(stockBadge(-2), 'sold_out');"),
])

ticket("t12", "rating", """
// Average review stars (1-5), one decimal. No reviews: null.
export function average(stars: number[]): number | null {
  return stars.reduce((a, b) => a + b, 0) / stars.length;
}
""", """
// Average review stars (1-5), one decimal. No reviews: null.
export function average(stars: number[]): number | null {
  const valid = stars.filter(s => s >= 1 && s <= 5);
  if (valid.length === 0) return null;
  return Math.round((valid.reduce((a, b) => a + b, 0) / valid.length) * 10) / 10;
}
""", [
    ("평균", "an average", "assert.equal(average([5, 4]), 4.5);"),
    ("리뷰가 없으면 null", "no reviews is null", "assert.equal(average([]), null);"),
], [
    ("[CI] 소수 첫째 자리", "[CI] one decimal", "assert.equal(average([5, 4, 4]), 4.3);"),
    ("[CI] 1~5 밖의 값은 무시", "[CI] values outside 1-5 are ignored", "assert.equal(average([5, 0, 6, 4]), 4.5);"),
])


def test_file(module, fn_import, cases, lang):
    lines = ["import { test } from 'node:test';", "import assert from 'node:assert/strict';",
             f"import {{ {fn_import} }} from '../src/tickets/{module}.ts';", ""]
    for ko, en, body in cases:
        name = (ko if lang == "ko" else en).replace("\\", "\\\\").replace("'", "\\'")
        lines.append(f"test('{name}', () => {{\n  {body}\n}});\n")
    return "\n".join(lines)


def export_name(src):
    return src.split("export function ")[1].split("(")[0]


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main():
    n = 0
    for lang in ("ko", "en"):
        base = ROOT / "content" / "commerce-api" / lang / "tickets"
        for tid, (module, buggy, fixed, public, hidden) in TICKETS.items():
            fn = export_name(buggy)
            write(base / f"{tid}.ts", buggy)
            write(base / f"{tid}_fixed.ts", fixed)
            write(base / f"{tid}.test.ts", test_file(module, fn, public, lang))
            write(ROOT / "content" / "ci" / lang / f"tk_{tid}" / f"ci_{module}.test.ts", test_file(module, fn, hidden, lang))
            n += 4
    print(f"{n} ticket files written")


if __name__ == "__main__":
    main()
