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
| 4 | 회고와 성과 면담 | 비난 없는 회고, 정규직 전환 평가, Brightloop 면담 지속 선택 → 챕터 결과 |

**시스템**
- 권한: 인턴·주니어는 PR을 올리고 리뷰 코멘트만 남김. 승인·병합은 시니어
- 판정은 결과 기반: 팀 테스트 + 숨겨진 **[CI] 추가 검증**, Git 상태, 리뷰
- **조사 노트**: 6개 업무에서 실제 단서 수집 → 가설 기록·수정 → 코드 검증 → Dashboard 조사 수첩. 힌트와 잘못된 가설, CI 실패 횟수에는 일괄 신뢰 감점이 없음
- 신뢰도 4축(기술 신뢰, 업무 신뢰, 친밀도, 의견 일치): **천천히 오르고(체감 감소), 실수하면 1.6배로 떨어짐**
- 컨디션: 일하면 줄고, 쉬거나 딴짓하면 회복. 바닥나면 모든 작업이 느려짐
- **Browser**: 사내 포털(커피 브레이크), DevDaily, Streamly, 익명 Lounge, Shoply(산 물건이 방에 놓임), Connectly(리크루터 오퍼)
- 딴짓하다 상사가 지나가면 3초 안에 업무 화면으로 바꿔야 함. 걸리면 신뢰도 하락
- 급여는 퇴근할 때 입금, 진행은 자동 저장
- 사운드는 전부 코드로 합성(에셋 파일 없음): 상황에 따라 분위기가 바뀌는 생성형 앰비언트 음악(집중·장애·퇴근), 사무실 공기음과 멀리서 들리는 동료 타이핑, 기계식 키보드, 절제된 OS 알림음, 결과를 알려 주는 피아노 음색. Dashboard에서 음악·효과음·사무실 소리 음량 조절
- 책상 화면: 기본 플레이 화면은 내 책상입니다. 모니터가 중앙에 크게, 창밖·화분·키보드·소품이 둘레에 보입니다. 정규직이 되면 **세로 보조 모니터**(시계·지금 업무·CI·알림·서비스 상태)가 설치되고, 다음 직급에서 데스크 매트와 명패가 생깁니다.
- 연출: 퇴근 시 모니터가 꺼지고 창밖이 밤으로 바뀌는 타임랩스, 아침 일출, 병합·승진 컨페티, 실패·적발 시 화면 흔들림, 뒤로 지나가는 상사 실루엣

## Chapter 2 · 내 이름이 적힌 업무 (8개 업무 완결)

챕터 1 결과 화면의 **챕터 2 시작하기**로 이어집니다. 기존 저장의 직급·관계·구매·커리어 선택을 유지합니다.

| 업무 | 플레이 |
|---|---|
| NXR-021 월요일의 빈칸 | Request Lab에서 고객 티켓과 요청 기록 조사, 재현 계획 기록 |
| NXR-022 재현되지 않습니다 | 실제 요청 함수를 실행하며 지연·재전송·요청 키를 비교 |
| NXR-023 같은 요청 두 번 | 순차 중복 방지 구현 → 로컬 테스트 → PR·추가 CI·동료 검토 → 현재 코드의 주문 수 확인 |
| NXR-024 남겨야 할 로그 | 구매자 정보를 찍는 디버그 로그를 허용 목록 방식으로 고치기 (Mina와 기준 합의) |
| NXR-025 기다리는 사람의 화면 | Sophie의 PR에서 timeout을 '실패'로 보여 주는 줄을 찾아 리뷰 → '확인 중' 상태 합의 |
| NXR-026 버튼 바깥의 중복 | Lab '동시' 타이밍으로 겹친 요청 재현 → 저장소의 원자적 선점(claim)으로 수정 → 추가 CI |
| NXR-027 고쳤다는 말의 조건 | Monitor에서 달빛상점에만 제한 적용 → 관찰 → 근거 카드 판단 → 다음 확인·담당 기록 (되돌리기 가능) |
| NXR-028 저녁 여섯 시의 답장 | Yuri와 함께 내부 용어·과한 약속 없이 고객 답장 작성 → 회고 → LEGACY-17 예고 |

수정 전의 **호출 2번 → 주문 2개**와 수정 후의 **호출 2번 → 주문 1개**를 같은 실험으로 비교합니다. 직접 수정하거나 힌트·AI 초안을 사용할 수 있습니다. AI 초안은 검증하지 않은 범위를 설명에 적어 두며, 그 범위에서 CI가 실패할 수 있습니다. 고객 창구 Yuri, 장부 사진·질문 습관·'Mira'의 정체 같은 곁가지 사건도 등장합니다.

## 실행
필요한 것: [Godot 4.7](https://godotengine.org/download), Git, Node.js 22.6 이상 (출시 버전에서는 게임에 포함할 예정)

1. Godot 프로젝트 매니저에서 `project.godot`를 가져온다(Import).
2. F5로 실행 → 언어와 이름을 고르고 입사.

조작
- **F2** 책상 보기 ↔ 화면 가까이 보기 · 창 제목 표시줄 드래그/더블클릭 · `–` 최소화
- **Ctrl+1~0** 독 앱 열기 · **Ctrl+W** 창 닫기 · **Ctrl+M** 최소화 · 독 아이콘을 다시 누르면 최소화/복원
- Terminal: **Tab** 자동 완성(명령·git 하위 명령·브랜치·경로), ↑/↓ 기록, **Ctrl+L** 지우기, **Ctrl+C** 입력 취소
- DevIDE: **Ctrl+S** 저장, **Ctrl+F** 찾기
- 막히면 **AICode → 힌트**. 딴짓 단속 이벤트는 Dashboard에서 끌 수 있음

## 샌드박스
게임 속 Git과 테스트는 실제 엔진으로 실행하며, 저장소와 Git 설정을 전용 폴더에 분리한다. **플레이어 Node 코드의 OS 수준 격리는 아직 미구현이다.**
- 위치: `%APPDATA%/Godot/app_userdata/Developer Life Simulator/sandbox/`
- 호스트 git 설정 무시(`GIT_CONFIG_NOSYSTEM`, 전용 `GIT_CONFIG_GLOBAL`, `GIT_CEILING_DIRECTORIES`), 화면에는 가상 경로만 표시
- 터미널은 허용된 git 명령·옵션만 실행하고 저장소 밖 경로는 거부. 원격 main은 hook으로 보호
- 처음부터: Dashboard → **처음부터 다시 시작**
- 저장 버전·이전 백업·손상 파일 복구와 Git 상태 변경 감지 지원. Git·테스트 실행 중에는 초기화를 기다려야 함

## 구조
```
scripts/main.gd                 방 + 모니터 + 2배 해상도 화면 + 연출
scripts/room/room.gd            벡터 사무실 (시간대별 창밖, 구매 아이템 표시)
scripts/desktop/                게임 속 OS: 데스크톱(튜토리얼 가이드, 딴짓 감시), 창, DevIDE, Terminal
scripts/apps/                   CodeHub, TeamChat, TaskBoard, Request Lab, Wiki, Monitor, AICode, Browser, Dashboard
scripts/services/request_lab.gd 실제 TypeScript 요청 함수를 실행하는 가상 조건 실험      (autoload: RequestLab)
scripts/services/workspace.gd   샌드박스 Git, 가상 경로, 테스트·CI, 동료(봇) 커밋      (autoload: Workspace)
scripts/services/codehub.gd     PR, CI, 리뷰, 시니어 병합                            (autoload: CodeHub)
scripts/autoload/game.gd        언어, 시간, 관계, 채팅, 돈, 컨디션, 저장               (autoload: Game)
scripts/story/story.gd          미션 진행, 이벤트 라우팅                              (autoload: Story)
scripts/story/side_events.gd    점심·커피챗·질문·체크인·잡 오퍼
scripts/story/chapters.gd       실행 일차와 챕터·서사 날짜·구현 범위
scripts/story/missions/         d1_01 ~ d4_10, c02_01 ~ c02_03 미션
scripts/autoload/sfx.gd         오디오 디렉터: 절차적 합성, 생성형 음악·분위기 전환, 효과음  (autoload: Sfx)
content/commerce-api/{ko,en}/   회사 저장소 템플릿과 미션 파일 (tools/gen_content.py로 생성)
content/ci/{ko,en}/             미션별 숨겨진 [CI] 검증 테스트
```

## 로드맵

진행 결과: [챕터 1 자동 검증과 저장 복구 기록](docs/QA_CHAPTER_01.md) · [챕터 2 구현과 검증](docs/QA_CHAPTER_02.md).

실행 순서와 완료 기준: [개발 실행 계획](docs/DEVELOPMENT_PLAN.md). 챕터 2 전체 8개 업무를 구현했습니다. 다음은 챕터 2 플레이테스트와 외부 테스트 빌드 준비입니다.

게임성: [플레이 흐름과 후속 설계](docs/GAMEPLAY.md). 조사 노트와 실패 감점 조정은 구현되어 있으며, 업무 전략·성장 도구·난이도 프로필은 후속 계획입니다.

장편 본편 기획: [전체 시나리오](docs/SCENARIO.md) · [96개 업무와 48개 선택 사건](docs/SCENARIO_MISSIONS.md) · [인물·분기·엔딩](docs/SCENARIO_CHARACTERS.md) · [챕터 2 대본](docs/SCENARIO_CHAPTER_02.md) · [제작 기준](docs/SCENARIO_PRODUCTION.md) · [멀티 스토리라인·이벤트 설계(논의용)](docs/STORYLINES.md). 현재 구현 범위는 위의 Chapter 1과 Chapter 2입니다.

1. ~~기술 검증~~ ✅  2. ~~Vertical Slice~~ ✅  3. ~~Chapter 1 확장 (인턴 4일, 튜토리얼, 한/영)~~ ✅
4. ~~Chapter 2 8개 업무 구현~~ → Node·Git 런타임 번들, 플레이어 코드 OS 수준 격리, Chapter 3 (LEGACY-17)
