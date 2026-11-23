# Developer Life Simulator

가상의 IT 회사 **NEXORA**에 입사해 실제 코드 작성, Git 협업, 코드 리뷰, 장애 대응을 경험하는 싱글플레이 개발자 커리어 시뮬레이션 게임.

- 플랫폼: PC (Windows / Steam)
- 엔진: **Godot 4.7** (GDScript) — [ADR-001](docs/ADR-001-engine.md)

## 실행
필요한 것: [Godot 4.7](https://godotengine.org/download), Git, Node.js 22.6 이상 (테스트 실행용, 출시 버전에서는 게임에 포함할 예정)

1. Godot 4.7을 설치한다.
2. Godot 프로젝트 매니저에서 이 폴더의 `project.godot`를 가져온다(Import).
3. F5로 실행한다.

첫 실행 때 회사 저장소가 `%APPDATA%/Godot/app_userdata/Developer Life Simulator/VirtualCompany/`에 만들어진다.
- `commerce-api/`: 플레이어가 작업하는 실제 Git 작업 사본
- `remotes/commerce-api.git`: 가상 `origin` (로컬 bare repo, main 브랜치 보호 hook 적용)

처음부터 다시 하려면 이 `VirtualCompany` 폴더를 지우면 된다.

조작: F2를 누르면 화면을 가까이 보거나 멀리 본다. 창은 제목 표시줄을 끌어 옮기고, 더블클릭하면 최대화하고, 오른쪽 아래 모서리를 끌어 크기를 바꾼다.

## 구조
```
scenes/main.tscn            진입 씬
scripts/main.gd             방 + 모니터 + 화면(SubViewport) + 전원 켜기 연출
scripts/desktop/desktop.gd  게임 속 OS: 상단 바, 독, 알림, 부팅
scripts/desktop/os_window.gd  드래그·리사이즈 가능한 앱 창
scripts/desktop/apps.gd     TeamChat / TaskBoard / Wiki / AICode
scripts/desktop/ide_app.gd  DevIDE: 실제 파일 편집, Ctrl+S 저장
scripts/desktop/terminal_app.gd  Terminal: 실제 git, npm test
scripts/services/workspace.gd  회사 저장소 생성, Git 상태 감시, 테스트 실행 (autoload: Workspace)
scripts/services/proc_job.gd   외부 프로세스 비동기 실행 + 타임아웃
scripts/autoload/game.gd    게임 시간, 미션 목표, Git 이벤트 → 동료 반응 (autoload: Game)
content/commerce-api/       미션 저장소 템플릿 (첫 실행 때 복사됨)
shaders/screen.gdshader     모니터 화면 효과 (비네트, 스캔라인, 글레어)
```

## 로드맵
1. ~~기술 검증: Editor + 실제 Git + 테스트 실행 연결~~ ✅
2. Vertical Slice: Chapter 1 "First Commit"
3. MVP: 12개 미션, 저장, 관계 시스템
4. Early Access: AI 에이전트, 사건, 커리어 확장
