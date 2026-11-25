// Average review stars (1-5), one decimal. No reviews: null.
export function average(stars: number[]): number | null {
  const valid = stars.filter(s => s >= 1 && s <= 5);
  if (valid.length === 0) return null;
  return Math.round((valid.reduce((a, b) => a + b, 0) / valid.length) * 10) / 10;
}
