// One CSV line for the seller's order export.
export function csvRow(values: string[]): string {
  return values
    .map(v => (/[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v))
    .join(',');
}
