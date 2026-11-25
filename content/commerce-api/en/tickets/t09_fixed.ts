// Store search: every word of the query must appear in the product name, ignoring case.
export function matches(query: string, name: string): boolean {
  const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const target = name.toLowerCase();
  return words.length > 0 && words.every(w => target.includes(w));
}
