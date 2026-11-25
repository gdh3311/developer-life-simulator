// Evaluates the repository's own pre-order code for the customer-facing store on moonlight.shop.
// Each module is optional: the store shows whatever has shipped so far.
const lang = process.argv[2] === 'en' ? 'en' : 'ko';
const out = { deadline: null, labels: null, cancel: null, errors: [] };

const deadline = { local: '2026-03-10T23:00', offsetMinutes: 540 }; // 23:00 KST = 14:00 UTC
try {
  const { isOpen } = await import('./deadline.ts');
  const at = (iso) => Date.parse(iso);
  out.deadline = {
    before: isOpen(deadline, at('2026-03-10T13:59:00Z')),
    at: isOpen(deadline, at('2026-03-10T14:00:00Z')),
    after: isOpen(deadline, at('2026-03-10T14:30:00Z')),
  };
} catch (e) { out.errors.push('deadline: ' + String(e?.message ?? e).slice(0, 120)); }

try {
  const { shippingLine } = await import('./labels.ts');
  out.labels = shippingLine(lang === 'en' ? 'Mar 20' : '3월 20일');
} catch (e) { out.errors.push('labels: ' + String(e?.message ?? e).slice(0, 120)); }

try {
  const { requestCancel } = await import('./cancel.ts');
  const orders = [
    { id: 'P-101', paid: false, stage: 'placed' },
    { id: 'P-102', paid: true, stage: 'placed' },
    { id: 'P-103', paid: true, stage: 'preparing' },
    { id: 'P-104', paid: true, stage: 'shipped' },
  ];
  out.cancel = orders.map(o => ({ ...o, result: requestCancel({ paid: o.paid, stage: o.stage }) }));
} catch (e) { out.errors.push('cancel: ' + String(e?.message ?? e).slice(0, 120)); }

console.log('CODIEN_STORE=' + JSON.stringify(out));
