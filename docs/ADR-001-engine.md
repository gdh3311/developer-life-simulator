# ADR-001: 게임 엔진 / 기술 스택 선정

- 상태: 채택 (2026-11-23)

## 결정
**Electron + React + TypeScript (electron-vite 빌드)**

| 구성 | 선택 |
|---|---|
| 런타임 | Electron (Chromium + Node.js) |
| UI | React + 자체 Window Manager |
| 코드 에디터 | Monaco Editor |
| 상태 관리 | Zustand |
| Git | 시스템 Git CLI + 로컬 bare repo를 `origin`으로 사용 |
| 저장 | SQLite (게임 상태) + Git (코드 이력) |
| 코드 실행 | 메인 프로세스와 분리된, 제한된 실행 프로세스 |
| 배포 | Steam (steamworks.js), Windows 우선 |

## 근거
- 게임의 핵심이 3D/물리가 아니라 **에디터·멀티 윈도우·터미널·파일 시스템·실제 Git**이다.
- Node.js가 내장돼 Git CLI, 테스트 러너(TS), 자식 프로세스를 바로 쓸 수 있다.
- Monaco는 웹 기반 에디터라 Electron에 그대로 들어간다.

## 검토한 대안
- **Unity / Godot**: 에디터·터미널·Git 연동을 직접 만들어야 하고 웹 UI 생태계를 쓸 수 없다.
- **Tauri**: 용량은 작지만 백엔드가 Rust이고, Node 기반 TS 테스트 러너는 따로 묶어서 배포해야 한다.

## 주의
- 렌더러는 `contextIsolation: true`, `sandbox: true`. Node 기능은 preload/IPC로만 노출한다.
- 플레이어 코드는 절대 메인 프로세스에서 실행하지 않는다 (기획서 10장 참고).
