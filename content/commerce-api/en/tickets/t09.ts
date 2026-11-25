// Store search: every word of the query must appear in the product name, ignoring case.
export function matches(query: string, name: string): boolean {
  return name.includes(query);
}
