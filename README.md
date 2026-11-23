# Developer Life Simulator

가상의 IT 회사 **NEXORA**에 입사해 실제 코드 작성, Git 협업, 코드 리뷰, 장애 대응을 경험하는 싱글플레이 개발자 커리어 시뮬레이션 게임.

- 플랫폼: PC (Windows / Steam)
- 엔진: **Godot 4.7** (GDScript) — [ADR-001](docs/ADR-001-engine.md)

## 게임 구성 (Chapter 1 · 첫 주 3일)

| DAY | 업무 | 핵심 경험 |
|---|---|---|
| 1 | 첫 출근 | 온보딩, 팀 채팅, 위키, 태스크보드 |
| 1 | #001 첫 버그 수정 | 테스트 → 브랜치 → 커밋 → push → PR → CI → Daniel의 리뷰(반박 가능) → 병합 |
| 1 | 로컬 main 최신화 | `git pull`, 원격과 로컬의 차이 |
| 1 | #005 16시의 사건 | 동료 기능이 회귀 버그를 냄. `git log`/`blame`으로 원인 찾기, 기능은 살리며 수정 |
| 2 | #006 첫 코드 리뷰 | Sophie의 PR에서 문제 줄을 짚어 리뷰. 놓치면 3일차에 결제 장애 |
| 2 | #004 배송비 기능 | 스펙 구현 + 경계값 테스트, Daniel의 리팩터링과 **실제 Merge Conflict**, PM의 일정 압박 |
| 3 | #007 로그인 장애 | Monitor 로그 분석, 시니어 휴가 중, **AI 위임**(그럴듯하지만 버그 있는 코드) 검증 |
| 3 | #008 쿠폰 결제 장애 | 2일차 리뷰에서 버그를 놓쳤을 때만 발생 |
| 3 | 회고와 성과 면담 | 비난 없는 회고, 관계·지표 기반 승급 |

- 판정은 결과 기반: 팀 테스트 + 숨겨진 **[CI] 추가 검증 테스트**, Git 상태, 리뷰 결과
- 동료 관계는 4개 축(기술 신뢰, 업무 신뢰, 친밀도, 의견 일치)으로 따로 움직임
- 시간은 하이브리드 턴제: 테스트·커밋·CI·리뷰 같은 행동을 할 때 게임 시간이 흐름
- 진행은 자동 저장되고, 다시 실행하면 이어서 플레이

## 실행
필요한 것: [Godot 4.7](https://godotengine.org/download), Git, Node.js 22.6 이상 (출시 버전에서는 Git과 Node를 게임에 포함할 예정)

1. Godot 프로젝트 매니저에서 `project.godot`를 가져온다(Import).
2. F5로 실행한다.

조작
- **F2**: 화면 가까이 보기 ↔ 방 둘러보기
- 창은 제목 표시줄을 끌어 옮기고, 더블클릭하면 최대화하고, 오른쪽 아래 모서리를 끌어 크기를 바꾼다.
- 막히면 **AICode → 힌트 받기**

## 샌드박스
게임 속 Git과 테스트는 실제 엔진으로 돌아가지만 PC 환경과 완전히 분리된 샌드박스 안에서만 동작한다.
- 위치: `%APPDATA%/Godot/app_userdata/Developer Life Simulator/sandbox/`
- 호스트의 git 설정을 무시한다 (`GIT_CONFIG_NOSYSTEM`, 샌드박스 전용 `GIT_CONFIG_GLOBAL`, `GIT_CEILING_DIRECTORIES`).
- 화면에는 가상 경로만 보인다: `~/commerce-api`, `nexora.dev:commerce/commerce-api.git`
- 터미널은 허용된 git 명령과 옵션만 실행하고, 저장소 밖의 경로는 거부한다.
- 원격 main은 pre-receive hook으로 보호된다. 병합은 CodeHub에서만 할 수 있다.
- 처음부터 다시 하려면 Dashboard의 **처음부터 다시 시작**을 누르거나 `sandbox` 폴더를 지운다.

## 구조
```
scripts/main.gd                 방 + 모니터 + 2배 해상도 화면(SubViewport) + 연출
scripts/room/room.gd            벡터로 그린 사무실 (창밖 하늘이 게임 시간에 따라 바뀜)
scripts/desktop/                게임 속 OS: 데스크톱, 창, DevIDE, Terminal
scripts/apps/                   CodeHub, TeamChat, TaskBoard, Wiki, Monitor, AICode, Dashboard
scripts/services/workspace.gd   샌드박스 Git, 가상 경로, 테스트·CI 실행, 동료(봇) 커밋   (autoload: Workspace)
scripts/services/codehub.gd     PR, CI, 리뷰, 병합                                    (autoload: CodeHub)
scripts/autoload/game.gd        시간, 관계, 채팅, 이슈, 통계, 저장                      (autoload: Game)
scripts/story/story.gd          미션 진행과 이벤트 라우팅                              (autoload: Story)
scripts/story/missions/         m01 ~ m09 미션 스크립트
content/commerce-api/           회사 저장소 템플릿(base)과 미션별 파일
content/ci/                     미션별 숨겨진 [CI] 검증 테스트
```

## 로드맵
1. ~~기술 검증: Editor + 실제 Git + 테스트 실행 연결~~ ✅
2. ~~Vertical Slice: Chapter 1 "First Commit"~~ ✅ (3일 · 9개 업무로 확장)
3. MVP: 12개 미션, 사운드, Node·Git 런타임 번들, 플레이어 코드 OS 수준 격리
4. Early Access: 새 회사, 프로덕션 배포, AI 에이전트 감독, 커리어 확장
