// NXR-STUDIO-2 · 달빛상점 봄 예약 판매 페이지
// 윤서진 대표가 고객에게 그대로 보여 줄 페이지예요. 상품을 채우고 아래 함수 세 개를 완성하세요.
// 이미지: 'tea' | 'cup' | 'cookie' | 'candle' | 'jam'    테마: 'night' | 'dawn' | 'paper'

export function createPage() {
  return {
    title: '달빛상점',
    headline: '봄밤에 어울리는 차와 간식',
    sub: '예약 마감 전에 주문하면 마감 다음 날 발송합니다.',
    theme: 'night',
    cta: '예약하기',
    deadline: { local: '2026-03-10T23:00', offsetMinutes: 540 },
    products: [
      { name: '벚꽃 녹차', price: 12000, stock: 30, image: 'tea', alt: '분홍 꽃잎이 뜬 녹차 한 잔' },
      { name: '달빛 머그', price: 18000, stock: 0, image: 'cup', alt: '초승달이 그려진 크림색 머그' },
      { name: '버터 쿠키', price: 6500, stock: 4, image: 'cookie', alt: '버터 쿠키 세 개' },
    ],
  };
}

// 가격 표시: 12000 → '12,000원'
export function formatPrice(won: number): string {
  return won.toLocaleString('en-US') + '원';
}

// 남은 시간: 0 이하 '마감', 60분 미만 'N분 남음', 그 이상 'H시간 남음' 또는 'H시간 M분 남음'
export function countdownLabel(minutesLeft: number): string {
  if (minutesLeft <= 0) return '마감';
  if (minutesLeft < 60) return `${minutesLeft}분 남음`;
  const h = Math.floor(minutesLeft / 60);
  const m = minutesLeft % 60;
  return m === 0 ? `${h}시간 남음` : `${h}시간 ${m}분 남음`;
}

// 재고가 있고 마감 전일 때만 예약할 수 있어요.
export function canReserve(stock: number, minutesLeft: number): boolean {
  return stock > 0 && minutesLeft > 0;
}
