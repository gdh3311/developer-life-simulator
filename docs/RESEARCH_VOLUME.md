# 볼륨 채우기 — 레퍼런스와 플레이어 선호 조사

조사일 2026년 11월 25일 · 대상: 개발·경영 시뮬레이션, 프로그래밍 퍼즐, 데스크톱 연출 게임, 생활 시뮬레이션의 리뷰·분석 자료 · 우리 게임의 내부 테스트 피드백(챕터 3~4 QA·구매자 리뷰)

> 출처 대부분이 리뷰 집계 사이트, 언론 리뷰, 사용자 리뷰다. 개발사의 공식 데이터는 아니므로 방향을 잡는 근거로만 쓴다.

## 1. 레퍼런스에서 본 것

| 레퍼런스 | 플레이어가 좋아한 것 | 플레이어가 불만인 것 | 우리 게임에 주는 교훈 |
|---|---|---|---|
| **Software Inc.** | 깊이. 오래 할수록 평가가 오름(집계상 2시간 미만 35% → 20시간 이상 97% 추천) | 후반이 반복적이고 쉬워짐, 후반 성장 부족, 튜토리얼 부족 | 초반 2시간이 관문이다. 후반에는 **새 규칙**이 필요하다 |
| **Game Dev Tycoon** | 초반 루프 | 후반에 슬라이더만 맞추는 반복, 목표가 사라져 지침 | 같은 행동을 숫자만 키워 반복시키지 않는다 |
| **Exapunks / Zachtronics** | 같은 퍼즐을 다시 푸는 최적화(명령 수·사이클), 다양한 풀이 | 너무 길고 난해한 후반 퍼즐, 보상 없는 숨은 방 | **결과 비교표**(내 풀이 vs 다른 사람 분포)가 재도전 이유가 된다 |
| **Papers, Please** | 매일 새 규칙이 하나씩 추가되는 진행 | 한 번 나오고 잊히는 규칙, 다양성 부족 | 하루 단위로 **작은 새 조건**을 넣고, 넣은 규칙은 다시 쓴다 |
| **Hacknet / Hypnospace Outlaw** | 이메일·사이트·파일을 뒤져 찾는 숨은 내용, 데스크톱 연출 | 선형적인 이야기, 스토리 외 콘텐츠 부족 | 이미 있는 Git 기록·Wiki·Relay에 **찾아낼 것**을 숨긴다 |
| **Stardew Valley** | 끝나는 시간이 다른 목표들("하루만 더"), 꾸러미 수집, 축제, 서로 이어진 시스템 | 일부에겐 "집안일 시뮬레이터" | 짧은 일과 긴 일이 겹쳐야 다음 날이 궁금해진다 |
| **PowerWash Simulator** | 짧고 만족스러운 작업, 완료 퍼센트, 즉각적인 결과 | 구조가 단조롭다는 의견 | **5~15분짜리 작은 일감**과 진행률 표시가 볼륨의 기본 단위가 된다 |
| **inZOI (2025 설문 700+명)** | — | 1위 불만: 시뮬레이션 깊이 부족, 어색한 사회적 상호작용 | 인물과의 관계가 반응해야 한다. 대사보다 **기억하는 동료**가 중요 |

## 2. 우리 플레이테스트에서 나온 요구 (챕터 3~4 리뷰)

- 배포한 결과를 직접 보고 싶다 → ATLAS·상점·캠페인 콘솔로 일부 해결
- 선택이 다음 날을 바꿨으면 좋겠다 → 챕터 4~5 일부 반영, 이벤트 카드에는 아직 약함
- 기록이 남고 다시 열렸으면 좋겠다 → Docs 문서함으로 해결
- 막혔을 때 어디를 봐야 할지 알고 싶다 → 미해결
- 숙련자는 챕터 1 Git 연습을 건너뛰고 싶다 → 미해결
- 횟수가 아니라 좋은 습관을 평가해 달라 → 일일 목표 개편으로 해결

## 3. 지금 우리 게임의 빈 곳

현재 분량은 주 업무 42개(챕터 1~5), 스토리라인 2개, 이벤트 카드 15장, 조사 사건 몇 개다. 주 업무를 끝내면 **그날 할 수 있는 실제 플레이가 없다.** 레퍼런스가 공통으로 말하는 위험(후반 반복, 목표 소진)이 바로 여기서 생긴다.

## 4. 볼륨 계획 (효과 대비 비용 순)

| 순위 | 기능 | 근거 | 분량 효과 |
|---|---|---|---|
| **1** | **작은 일감 보드** — 동료·고객이 던지는 5~15분짜리 실제 버그 수정. 브랜치·테스트·PR·숨은 CI까지 진짜로 진행. 챕터마다 새 일감이 열리고 하루 2개까지 | PowerWash(짧은 일+진행률), Stardew(끝나는 시간이 다른 목표), Game Dev Tycoon(목표 소진 방지) | 일감 12개 × 10분 ≈ **2시간**, 반복 가능 |
| **2** | **결과 비교표** — 일감·업무를 마치면 내 기록(CI 시도, 추가 테스트, 걸린 시간)을 팀 분포와 비교 | Exapunks 히스토그램 | 재도전 동기 |
| **3** | **이벤트 카드 확장 + 다음 날 결과** — 선택이 다음 날 카드나 대사를 부르는 연쇄 카드 | Papers, Please, 우리 피드백("다음 날이 바뀌길") | 카드 15 → 27장 |
| 4 | 숨은 발견 수집(사내 비화) — Git 기록·Wiki·Relay 구석의 10개 | Hacknet, Hypnospace | 탐색 30~60분 |
| 5 | 동료 개인 이야기(아크 C·D: 오픈소스, 리드) | inZOI 설문, STORYLINES.md | 아크당 1~2시간 |
| 6 | 막혔을 때 도움 패널, 챕터 1 연습 건너뛰기 | 우리 피드백, Software Inc. 튜토리얼 불만 | 이탈 방지 |

이번 1차 제작은 **1~3번**이다.

## 5. 1차 제작 기준

**작은 일감**
- 일감은 `src/tickets/` 아래 독립 모듈이라 주 업무 파일과 충돌하지 않는다.
- 일감을 받으면 의뢰한 동료가 main에 모듈과 공개 테스트를 올린다. 브랜치 이름은 `ticket/<id>`.
- 공개 테스트 하나는 처음부터 빨간불이고, CI에는 숨은 검증 2개가 더 있다.
- 동료가 CI 통과 후 리뷰·병합한다. 보상은 돈, 관계, 커리어 경험치.
- 챕터 2부터 4개, 챕터 3에서 4개, 챕터 4부터 4개가 더 열린다. 동시에 하나만 진행한다.

**결과 비교표**
- 항목: 걸린 게임 시간, CI 실행 횟수, 추가한 테스트 수.
- 팀 분포는 일감별로 고정된 가상 기록 20개다. 내 기록이 어디쯤인지 막대로 보여 준다.

**이벤트 카드**
- 새 카드 12장. 그중 6장은 선택에 따라 다음 날 다른 카드가 이어진다.

## 출처

- Software Inc.: [Steam](https://store.steampowered.com/app/362620/Software_Inc), [Vaporlens 집계](https://vaporlens.app/app/362620/software_inc/stats/details), [RAWG 리뷰](https://rawg.io/games/software-inc/reviews)
- Game Dev Tycoon: [Metacritic 사용자 리뷰](https://legacy.prod.metacritic.com/game/pc/game-dev-tycoon/user-reviews), [Vaporlens](https://vaporlens.app/app/239820/game_dev_tycoon), [Destructoid](https://www.destructoid.com/reviews/review-game-dev-tycoon/)
- Exapunks: [PC Gamer](https://www.pcgamer.com/au/exapunks-review), [Backloggd](https://backloggd.com/games/exapunks/), [OpenCritic](https://opencritic.com/game/6785/exapunks)
- Papers, Please: [PC Gamer](https://www.pcgamer.com/uk/papers-please-review-1), [Wiki](https://papersplease.fandom.com/wiki/Papers,_Please), [Critical Video Game Studies](https://criticalvideogamestudies.com/?p=5558)
- Hacknet: [GOG 사용자 리뷰](https://gog.com/forum/hacknet/hacknet_review), [Operation Rainfall](https://operationrainfall.com/2017/03/15/review-hacknet-2/2)
- Hypnospace Outlaw: [PC Gamer](https://pcgamer.com/hypnospace-outlaw-review), [Wikipedia](https://en.wikipedia.com/wiki/Dreamsettler)
- Stardew Valley: [Super Jump(Medium)](https://medium.com/super-jump/what-makes-a-game-about-mundane-chores-hopelessly-addictive-ab136266ebcf), [GDC 내러티브 리뷰](https://media.gdcvault.com/gdc2024/GNR/Papers/brooke+glasier+-+game+narrative+review+2023+-+stardew+valley!.docx.pdf), [NPR](https://www.npr.org/2025/01/24/g-s1-44510/the-legacy-and-future-of-the-farming-game-stardew-valley)
- PowerWash Simulator: [Kotaku 개발자 인터뷰](https://kotaku.com/powerwash-sim-devs-on-making-cleaning-fun-advanced-cro-1847319502), [GameSpot](https://gamespot.com/reviews/powerwash-simulator-review-filthy-rich/1900-6417923/)
- inZOI 설문: [PC Gamer](https://www.pcgamer.com/games/life-sim/inzois-biggest-problems-right-now-are-overwhelmingly-the-fact-its-lacking-simulation-content-and-its-painfully-awkward-social-interactions-player-survey-reveals), [GamesRadar](https://www.gamesradar.com/games/simulation/the-sims-competitor-inzoi-has-one-big-issue-beating-every-other-problem-in-a-new-player-survey-its-lacking-simulation-content-which-seems-kinda-bad)
