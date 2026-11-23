extends RefCounted
## Execution days stay stable for old saves; chapter and narrative date are presentation metadata.

const DATA := {
	1: {"title": {"ko": "첫 출근", "en": "First days"}, "period": {"ko": "첫 번째 달", "en": "Month one"}, "first_day": 1, "last_day": 4, "planned": 10, "complete": true},
	2: {"title": {"ko": "내 이름이 적힌 업무", "en": "A task with my name on it"}, "period": {"ko": "두 번째 달", "en": "Month two"}, "first_day": 5, "last_day": 5, "planned": 8, "complete": false},
}


static func for_day(day: int) -> int:
	return 2 if day >= 5 else 1


static func weekday(day: int) -> int:
	return (day - int(DATA[for_day(day)]["first_day"])) % 7
