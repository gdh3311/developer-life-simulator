# Developer Life Simulator

가상의 IT 회사 **NEXORA**에 입사해 실제 코드 작성, Git 협업, 코드 리뷰, 장애 대응을 경험하는 싱글플레이 개발자 커리어 시뮬레이션 게임.

- 플랫폼: PC (Windows / Steam)
- 엔진: **Godot 4.7** (GDScript) — [ADR-001](docs/ADR-001-engine.md)

## 실행
1. [Godot 4.7](https://godotengine.org/download)을 설치한다.
2. Godot 프로젝트 매니저에서 이 폴더의 `project.godot`를 가져온다(Import).
3. F5로 실행한다.

조작: F2를 누르면 화면을 가까이 보거나 멀리 본다. 창은 제목 표시줄을 끌어 옮기고, 더블클릭하면 최대화하고, 오른쪽 아래 모서리를 끌어 크기를 바꾼다.

## 구조
```
scenes/main.tscn            진입 씬
scripts/main.gd             방 + 모니터 + 화면(SubViewport) + 전원 켜기 연출
scripts/desktop/desktop.gd  게임 속 OS: 상단 바, 독, 알림, 부팅
scripts/desktop/os_window.gd  드래그·리사이즈 가능한 앱 창
scripts/desktop/apps.gd     DevIDE / Terminal / TeamChat / TaskBoard / Wiki / AICode
scripts/autoload/game.gd    게임 시간(하이브리드 턴제), 전역 상태
shaders/screen.gdshader     모니터 화면 효과 (비네트, 스캔라인, 글레어)
```

## 로드맵
1. 기술 검증: Editor + 실제 Git + 테스트 실행 연결
2. Vertical Slice: Chapter 1 "First Commit"
3. MVP: 12개 미션, 저장, 관계 시스템
4. Early Access: AI 에이전트, 사건, 커리어 확장
