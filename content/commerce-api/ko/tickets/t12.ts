// Average review stars (1-5), one decimal. No reviews: null.
export function average(stars: number[]): number | null {
  return stars.reduce((a, b) => a + b, 0) / stars.length;
}
