// NXR-STUDIO · Packet Run beta
// S: start  E: exit  P: packet  #: wall  .: floor
// Add a second P and adjust the move budget so both packets can reach the exit.
// P를 하나 더 배치하고, 두 패킷을 모아 출구에 도달할 수 있도록 이동 횟수를 정하세요.

export function createLevel() {
  return {
    title: 'Packet Run — Beta',
    intro: 'Deliver every packet before the signal runs out.',
    moveLimit: 9,
    rows: [
      'S..#..',
      '.#.P..',
      '.#.#.E',
      '...#..',
      '#.....',
    ],
  };
}

export function canExit(collected: number, total: number): boolean {
  // TODO: Open the exit only when all the packets have been collected.
  // 모든 패킷을 모았을 때만 출구를 열도록 수정하세요.
  return true;
}
