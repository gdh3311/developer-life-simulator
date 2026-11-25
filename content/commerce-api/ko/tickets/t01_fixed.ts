// Product URL slugs. Policy: lower case, words joined by '-', no other symbols.
export function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9가-힣\s_-]/g, ' ')
    .split(/[\s_-]+/)
    .filter(Boolean)
    .join('-');
}
