// Boxes to pack: up to 6 items per box. Leftover items need one more box.
export function boxCount(items: number): number {
  return Math.floor(items / 6) + 1;
}
