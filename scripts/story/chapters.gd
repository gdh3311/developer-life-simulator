extends RefCounted
## Execution days stay stable for old saves; chapter and narrative date are presentation metadata.

const DATA := {
	1: {"title": {"ko": "첫 출근", "en": "First days"}, "period": {"ko": "첫 번째 달", "en": "Month one"}, "first_day": 1, "last_day": 4, "planned": 10, "complete": true},
	2: {"title": {"ko": "내 이름이 적힌 업무", "en": "A task with my name on it"}, "period": {"ko": "두 번째 달", "en": "Month two"}, "first_day": 5, "last_day": 7, "planned": 8, "complete": true},
	3: {"title": {"ko": "처음부터 끝까지", "en": "From start to finish"}, "period": {"ko": "네 번째 달", "en": "Month four"}, "first_day": 8, "last_day": 10, "planned": 8, "complete": true},
	4: {"title": {"ko": "오래된 결정", "en": "An old decision"}, "period": {"ko": "일곱 번째 달", "en": "Month seven"}, "first_day": 11, "last_day": 13, "planned": 8, "complete": true},
	5: {"title": {"ko": "사람들이 몰려오는 날", "en": "The day everyone shows up"}, "period": {"ko": "열 번째 달", "en": "Month ten"}, "first_day": 14, "last_day": 16, "planned": 8, "complete": true},
	6: {"title": {"ko": "같은 업계 다른 책상", "en": "Same industry, different desk"}, "period": {"ko": "열한 번째 달", "en": "Month eleven"}, "first_day": 17, "last_day": 18, "planned": 6, "complete": true},
}


static func for_day(day: int) -> int:
	if day >= 17:
		return 6
	if day >= 14:
		return 5
	if day >= 11:
		return 4
	if day >= 8:
		return 3
	return 2 if day >= 5 else 1


static func weekday(day: int) -> int:
	return (day - int(DATA[for_day(day)]["first_day"])) % 7
