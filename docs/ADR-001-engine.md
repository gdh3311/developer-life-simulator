# ADR-001: 게임 엔진 선정

- 상태: 채택 (2026-11-23)
- 이전 결정 (Electron + React)을 대체함

## 결정
**Godot 4 (4.7, GDScript, GL Compatibility 렌더러)**

## 근거
- 업무 도구가 아니라 **게임**처럼 느껴져야 한다. 연출(트윈, 셰이더, 사운드, 카메라)이 엔진에 기본으로 들어 있다.
- 플레이어는 **책상 앞에서 모니터를 보는 1인칭 시점**이다. 게임 OS 전체를 `SubViewport`에 그리고, 그 화면을 방 안의 모니터에 띄운다.
  - 이 구조 덕분에 모니터 전원 켜기, 화면 글레어와 비네트, 화면 가까이 보기(F2) 같은 연출을 쉽게 넣을 수 있다.
  - 나중에 사무실 씬, 동료 방문, 퇴근 연출로 확장할 수도 있다.
- 무료(MIT)이고 가볍다. Steam 연동은 GodotSteam을 쓴다.
- `CodeEdit`(구문 강조, 줄 번호), `RichTextLabel`, `Tree` 같은 UI 노드가 이미 있어 IDE·채팅·위키를 만들기 좋다.
- 실제 Git은 `OS.execute` / `OS.create_process`로 시스템 Git CLI를 호출한다.

## 검토한 대안
- **Electron + React**: 에디터와 웹 UI는 가장 쉽지만 게임다운 연출이 약하다.
- **Unity**: 가능하지만 UI 작업이 무겁고, 이 게임에 필요한 장점이 Godot보다 크지 않다.

## 기술 검증 결과 (2026-11-23)
- 실제 Git: `OS.execute_with_pipe`로 시스템 git을 별도 스레드에서 실행. 브랜치, 커밋, push를 감지해 게임 이벤트로 바꾸는 것까지 동작 확인.
- 가상 origin: 로컬 bare repo + `pre-receive` hook으로 main 브랜치 보호.
- 테스트: `node --experimental-strip-types --test --test-reporter=tap`, TAP 결과를 파싱해 게임 안에 표시. 20초 타임아웃이 지나면 프로세스 트리를 강제 종료(무한 루프 대응).

## 열린 문제
- **Node 배포**: 지금은 시스템에 설치된 Node를 쓴다. 출시 전에 Node 런타임을 게임에 포함해야 한다.
- **샌드박스**: 지금은 타임아웃만 있다. 파일·네트워크 제한(OS 수준 격리)은 아직 없다.
- **export**: `content/` 폴더(.ts 등 리소스가 아닌 파일)를 export 필터에 포함해야 한다.
- **에디터 품질**: `CodeEdit`에는 자동완성·타입 오류 표시가 없다. 필요하면 LSP(tsserver) 연동을 검토한다.

## 업데이트 (2026-11-23, Chapter 1 확장)
- 다국어: `Game.L(ko, en)`는 바로 표시할 문자열, `Game.LL(ko, en)`는 저장했다가 나중에 `Game.tx()`로 표시하는 문자열(채팅, PR 코멘트, 이슈 등)에 쓴다. 언어를 바꾸면 씬을 다시 불러온다.
- 회사 저장소 콘텐츠(코드 주석, 테스트 이름, 숨겨진 CI 테스트)는 `tools/gen_content.py`로 ko/en 두 벌을 만든다. 저장소 언어는 새 게임을 만들 때 정해진다.
- 권한 모델: 플레이어(인턴·주니어)는 PR 생성과 리뷰 코멘트만 할 수 있다. 승인·병합은 NPC 시니어가 `CodeHub._try_auto_merge`로 처리한다.
