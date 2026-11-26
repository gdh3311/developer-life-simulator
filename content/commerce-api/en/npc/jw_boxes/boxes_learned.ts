// Boxes to pack: up to 6 items per box. Leftover items need one more box.
// Like the shipping fee PR, leftovers round up. Tests cover 7 and 0 items.
export function boxCount(items: number): number {
  return Math.ceil(items / 6);
}
