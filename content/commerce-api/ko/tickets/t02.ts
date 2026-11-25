// Which rows a page shows (1-based, inclusive). Out-of-range pages show nothing (null).
export function pageRange(page: number, size: number, total: number): { from: number; to: number } | null {
  return { from: (page - 1) * size, to: page * size };
}
