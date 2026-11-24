// NXR-STUDIO-2 · Moonlight spring pre-order page
// Seojin from Moonlight will show this page to customers as is. Fill in the products and finish the three functions.
// image: 'tea' | 'cup' | 'cookie' | 'candle' | 'jam'    theme: 'night' | 'dawn' | 'paper'

export function createPage() {
  return {
    title: 'Moonlight',
    headline: 'Tea and treats for spring nights',
    sub: 'Order before the deadline and we ship the next day.',
    theme: 'night',
    cta: 'Pre-order',
    deadline: { local: '2026-03-10T23:00', offsetMinutes: 540 },
    products: [
      { name: 'Cherry blossom tea', price: 12000, stock: 30, image: 'tea', alt: '' },
      { name: 'Moonlight mug', price: 18000, stock: 0, image: 'cup', alt: '' },
    ],
  };
}

// Price: 12000 → '₩12,000'
export function formatPrice(won: number): string {
  return '₩' + won;
}

// Time left: 0 or less 'Closed', under 60 'N min left', otherwise 'H h left' or 'H h M min left'
export function countdownLabel(minutesLeft: number): string {
  return minutesLeft + ' min left';
}

// Pre-orders are open only while there is stock and the deadline hasn't passed.
export function canReserve(stock: number, minutesLeft: number): boolean {
  return stock >= 0;
}
