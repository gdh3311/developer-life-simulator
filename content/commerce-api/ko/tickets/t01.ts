// Product URL slugs. Policy: lower case, words joined by '-', no other symbols.
export function slugify(name: string): string {
  return name.toLowerCase().replace(' ', '-');
}
