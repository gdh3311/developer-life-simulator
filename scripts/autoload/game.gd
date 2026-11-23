extends Node
## Global game state: the in-game clock (hybrid turn-based) and event bus.

signal time_changed(day: int, minutes: int)

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const DAY_START := 9 * 60

var day := 0
var minutes := DAY_START


## Advance game time after a meaningful action (see GDD 7.1).
func advance(mins: int) -> void:
	minutes += mins
	time_changed.emit(day, minutes)


func next_day() -> void:
	day += 1
	minutes = DAY_START
	time_changed.emit(day, minutes)


func clock_text() -> String:
	return "%s %02d:%02d" % [DAY_NAMES[day % 7], floori(minutes / 60.0), minutes % 60]
