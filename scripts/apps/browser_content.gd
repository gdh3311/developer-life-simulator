extends RefCounted
## Original publications hosted by the in-game browser.

const ARTICLES := [
	{
		"id": "retry", "art": 0, "desk": {"ko": "시스템", "en": "SYSTEMS"},
		"title": {"ko": "같은 주문이 두 번 들어오는 이유", "en": "Why the same order arrives twice"},
		"summary": {"ko": "결제창이 잠깐 멈춘 사이, 고객과 서버는 서로 다른 이야기를 본다.", "en": "When checkout stalls, the customer and the server see different stories."},
		"by": "J. Han", "minutes": 3,
		"body": [
			{"ko": "저녁 6시, 카운터에 같은 메뉴가 적힌 전표가 두 장 놓였다. 손님은 구매 버튼을 한 번만 눌렀고, 화면에는 오래 돌아가는 로딩 표시가 남았다. 서버는 첫 번째 요청을 처리했지만 응답이 늦어졌다. 기다리던 앱이 요청을 한 번 더 보냈다.", "en": "At six, two identical tickets landed on the counter. The customer had clicked once, then watched a spinner. The server had processed the first request, but the response came slowly. The waiting app sent the request again."},
			{"ko": "재전송 자체는 정상 동작이다. 중요한 건 서버가 두 전송을 같은 구매 시도로 알아보는지다. 응답 지연을 켠 실험과 끈 실험을 비교하면, 두 번째 전표에 화면의 더블 클릭이 필요한지부터 확인할 수 있다.", "en": "Retrying is normal. What matters is whether the server recognizes both sends as one purchase attempt. Compare a delayed response with an immediate one. You may find that a second ticket never required a second click."},
			{"ko": "전표 두 장이 결제 두 건을 뜻하지는 않는다. 주문 번호와 결제 참조를 따로 확인하고, 확실해질 때까지 고객에게는 관찰한 사실만 전달한다.", "en": "Two tickets do not establish two charges. Track order IDs and payment references separately. While the payment check is still open, tell the customer what you have observed."},
		],
	},
	{
		"id": "review", "art": 1, "desk": {"ko": "현장", "en": "WORKPLACE"},
		"title": {"ko": "PR 리뷰는 왜 채팅보다 느릴까", "en": "Why a PR review takes longer than a chat"},
		"summary": {"ko": "읽기 쉬운 변경 설명 하나가 리뷰어의 오후를 바꾼다.", "en": "A clear change description can transform a reviewer's afternoon."},
		"by": "M. Rhee", "minutes": 2,
		"body": [
			{"ko": "작은 PR에서 리뷰어가 가장 오래 붙잡고 있는 곳은 코드 한 줄이 아닐 때가 많다. 이 변경이 어떤 실패를 막는지 찾아 이전 이슈와 테스트를 오가는 데 시간이 든다.", "en": "The longest part of a small review often happens outside the diff. The reviewer jumps between the ticket and the tests to work out which failure the change prevents."},
			{"ko": "변경 설명에 재현 조건과 확인 결과를 함께 적어 보자. 여전히 병합을 지연시킬 만한 위험이 있다면 본문 맨 아래에서 구체적으로 말하면 된다.", "en": "Put the reproduction conditions and the verification result in the description. If a risk still matters for the merge, call it out in one concrete sentence."},
		],
	},
	{
		"id": "handoff", "art": 2, "desk": {"ko": "칼럼", "en": "COLUMN"},
		"title": {"ko": "퇴근 후에도 기억나는 장애", "en": "The incident you remember on the train home"},
		"summary": {"ko": "다음 당직자가 같은 질문을 처음부터 하지 않게 하려면.", "en": "Give the next engineer a place to pick up the investigation."},
		"by": "S. Choi", "minutes": 2,
		"body": [
			{"ko": "퇴근길에 제일 많이 떠오르는 건 빨간 그래프가 아니다. 누가 마지막으로 고객에게 연락했는지, 다음 사람이 누군지, 아침에 무엇을 다시 확인해야 하는지다.", "en": "The red graph is rarely what sticks on the way home. You remember who last spoke to the customer, who takes over, and what still needs checking in the morning."},
			{"ko": "좋은 인계에는 현재 상태, 마지막으로 확인한 시각, 다음 확인 담당자가 들어간다. 일기를 쓸 필요는 없다. 동료가 그 세 줄을 읽고 정확히 어디에서 이어갈지만 알면 된다.", "en": "A good handoff records the current state, the last verified time, and the next owner. Three lines will do if they tell the next person where to pick up."},
		],
	},
]

const VIDEOS := [
	{
		"id": "git", "ko": "Git 스냅샷을 따라가 보기", "en": "Following a Git snapshot",
		"art": 0, "channel": "Merge Room", "duration": 30, "views": "18.4K", "fun": false,
		"captions": [
			{"ko": "파일을 고른 뒤 스테이징에 넣는다.", "en": "Stage the files you want in the snapshot."},
			{"ko": "커밋은 그 시점의 변경 이력을 남긴다.", "en": "A commit records that snapshot in history."},
			{"ko": "동료가 보려면 공유 브랜치에 push한다.", "en": "Push to a shared branch so a teammate can review it."},
		],
	},
	{
		"id": "keyboard", "ko": "비 오는 저녁의 데스크 셋업", "en": "A desk setup for a rainy evening",
		"art": 1, "channel": "After Five", "duration": 27, "views": "42.7K", "fun": true,
		"captions": [
			{"ko": "키보드를 책상 가장자리에서 한 뼘 안쪽으로 옮긴다.", "en": "Slide the keyboard a hand's width away from the edge."},
			{"ko": "저녁에는 모니터보다 책상 위 조명을 먼저 낮춘다.", "en": "At dusk, dim the desk lamp before the display."},
			{"ko": "마지막으로 내일 처음 할 일을 한 줄 남겨 둔다.", "en": "Leave one line about where to start tomorrow."},
		],
	},
	{
		"id": "rail", "ko": "막차 창가에서 본 도시", "en": "The city from the last train",
		"art": 2, "channel": "Window Seat", "duration": 24, "views": "9.6K", "fun": true,
		"captions": [
			{"ko": "플랫폼 조명이 물방울에 번진다.", "en": "Platform lights scatter through the raindrops."},
			{"ko": "차창 안에는 빈 자리와 코트를 입은 사람의 실루엣만 남았다.", "en": "Inside the reflection, an empty seat and the shape of a coat remain."},
			{"ko": "전철이 출발하면 화면에는 잠시 강 건너 불빛만 남는다.", "en": "As the train pulls away, the lights across the river linger."},
		],
	},
]
