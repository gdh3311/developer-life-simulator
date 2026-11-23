# Developer Life Simulator

가상의 IT 회사 **NEXORA**에 **인턴**으로 입사해 실제 코드 작성, Git 협업, 코드 리뷰, 장애 대응을 경험하는 싱글플레이 개발자 커리어 시뮬레이션 게임. **한국어 / English** 지원.

- 플랫폼: PC (Windows / Steam)
- 엔진: **Godot 4.7** (GDScript) — [ADR-001](docs/ADR-001-engine.md)

## Chapter 1 · 인턴의 첫 주 (4일, 10개 업무)

| DAY | 업무 | 핵심 경험 |
|---|---|---|
| 1 | 첫 출근 (튜토리얼) | 팀 채팅, 위키, 터미널 기초(`help`, `ls`, `cat`), `git config`, `git status/log` |
| 1 | 첫 PR (튜토리얼) | README 오타 수정: 브랜치 → 수정 → `git diff` → 커밋 → push → PR → 시니어가 병합 |
| 1 | 병합 후 정리 (튜토리얼) | `git pull`, `git branch -d` · 점심 초대 |
| 2 | #001 첫 버그 수정 | 재현 테스트 받기, `npm test`, Daniel의 리뷰(반박 가능) |
| 2 | #005 16시의 사건 | 동료 기능이 회귀 버그를 냄. `git log`/`blame`으로 원인 찾기 · 커피챗, Sophie의 git 질문 |
| 3 | #006 리뷰 코멘트 | Sophie의 PR에 문제 줄을 짚어 코멘트(주니어는 승인 불가). 놓치면 4일차 결제 장애 |
| 3 | #004 배송비 기능 | 경계값 테스트, Daniel 리팩터링과 **실제 Merge Conflict**, PM 압박(정직/부탁/우회) · 진행 체크인 · 잡 오퍼 |
| 4 | #007 로그인 장애 | Monitor 로그, 시니어 휴가, **AI 위임**(그럴듯하지만 버그 있는 코드) 검증 |
| 4 | #008 쿠폰 결제 장애 | 3일차 리뷰에서 버그를 놓쳤을 때만 |
| 4 | 회고와 성과 면담 | 비난 없는 회고, 정규직 전환 평가, 이직 오퍼 결정 → 엔딩 분기 |

**시스템**
- 권한: 인턴·주니어는 PR을 올리고 리뷰 코멘트만 남김. 승인·병합은 시니어
- 판정은 결과 기반: 팀 테스트 + 숨겨진 **[CI] 추가 검증**, Git 상태, 리뷰
- 신뢰도 4축(기술 신뢰, 업무 신뢰, 친밀도, 의견 일치): **천천히 오르고(체감 감소), 실수하면 1.6배로 떨어짐**
- 컨디션: 일하면 줄고, 쉬거나 딴짓하면 회복. 바닥나면 모든 작업이 느려짐
- **Browser**: 사내 포털(커피 브레이크), DevDaily, Streamly, 익명 Lounge, Shoply(산 물건이 방에 놓임), Connectly(리크루터 오퍼)
- 딴짓하다 상사가 지나가면 3초 안에 업무 화면으로 바꿔야 함. 걸리면 신뢰도 하락
- 급여는 퇴근할 때 입금, 진행은 자동 저장

## 실행
필요한 것: [Godot 4.7](https://godotengine.org/download), Git, Node.js 22.6 이상 (출시 버전에서는 게임에 포함할 예정)

1. Godot 프로젝트 매니저에서 `project.godot`를 가져온다(Import).
2. F5로 실행 → 언어와 이름을 고르고 입사.

조작: **F2** 화면 가까이 보기 ↔ 방 둘러보기 · 창 제목 표시줄 드래그/더블클릭 · 막히면 **AICode → 힌트**

## 샌드박스
게임 속 Git과 테스트는 실제 엔진으로 돌지만 PC 환경과 완전히 분리된다.
- 위치: `%APPDATA%/Godot/app_userdata/Developer Life Simulator/sandbox/`
- 호스트 git 설정 무시(`GIT_CONFIG_NOSYSTEM`, 전용 `GIT_CONFIG_GLOBAL`, `GIT_CEILING_DIRECTORIES`), 화면에는 가상 경로만 표시
- 터미널은 허용된 git 명령·옵션만 실행하고 저장소 밖 경로는 거부. 원격 main은 hook으로 보호
- 처음부터: Dashboard → **처음부터 다시 시작**

## 구조
```
scripts/main.gd                 방 + 모니터 + 2배 해상도 화면 + 연출
scripts/room/room.gd            벡터 사무실 (시간대별 창밖, 구매 아이템 표시)
scripts/desktop/                게임 속 OS: 데스크톱(튜토리얼 가이드, 딴짓 감시), 창, DevIDE, Terminal
scripts/apps/                   CodeHub, TeamChat, TaskBoard, Wiki, Monitor, AICode, Browser, Dashboard
scripts/services/workspace.gd   샌드박스 Git, 가상 경로, 테스트·CI, 동료(봇) 커밋      (autoload: Workspace)
scripts/services/codehub.gd     PR, CI, 리뷰, 시니어 병합                            (autoload: CodeHub)
scripts/autoload/game.gd        언어, 시간, 관계, 채팅, 돈, 컨디션, 저장               (autoload: Game)
scripts/story/story.gd          미션 진행, 이벤트 라우팅                              (autoload: Story)
scripts/story/side_events.gd    점심·커피챗·질문·체크인·잡 오퍼
scripts/story/missions/         d1_01 ~ d4_10 미션
content/commerce-api/{ko,en}/   회사 저장소 템플릿과 미션 파일 (tools/gen_content.py로 생성)
content/ci/{ko,en}/             미션별 숨겨진 [CI] 검증 테스트
```

## 로드맵
1. ~~기술 검증~~ ✅  2. ~~Vertical Slice~~ ✅  3. ~~Chapter 1 확장 (인턴 4일, 튜토리얼, 한/영)~~ ✅
4. 다음: 사운드, Node·Git 런타임 번들, 플레이어 코드 OS 수준 격리, Chapter 2
