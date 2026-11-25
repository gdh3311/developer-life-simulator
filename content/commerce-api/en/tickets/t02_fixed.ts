// Which rows a page shows (1-based, inclusive). Out-of-range pages show nothing (null).
export function pageRange(page: number, size: number, total: number): { from: number; to: number } | null {
  const from = (page - 1) * size + 1;
  if (page < 1 || size < 1 || from > total) return null;
  return { from, to: Math.min(page * size, total) };
}
