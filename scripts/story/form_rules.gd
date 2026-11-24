extends RefCounted
## Shared validation for Docs forms (used by missions and storyline arcs).


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


static func picked(picks: Dictionary, slot: String) -> Array:
	var v = picks.get(slot, [])
	if typeof(v) == TYPE_ARRAY:
		return v
	return [] if String(v) == "" else [String(v)]


static func option(spec: Dictionary, slot_id: String, option_id: String) -> Dictionary:
	for slot in spec["slots"]:
		if slot["id"] == slot_id:
			for o in slot["options"]:
				if o["id"] == option_id:
					return o
	return {}


static func cost(spec: Dictionary, slot_id: String, picks: Dictionary) -> int:
	var total := 0
	for id in picked(picks, slot_id):
		total += int(option(spec, slot_id, id).get("cost", 0))
	return total


## Empty slots, too many picks and unknown options.
static func missing(spec: Dictionary, picks: Dictionary) -> Array:
	var notes: Array = []
	for slot in spec["slots"]:
		var chosen := picked(picks, slot["id"])
		var label: Dictionary = slot["label"]
		if chosen.is_empty():
			notes.append({"ko": "'%s' 칸이 비어 있어요." % label["ko"], "en": "The '%s' field is empty." % label["en"]})
			continue
		if not slot.get("multi", false) and chosen.size() > 1:
			notes.append({"ko": "'%s'은 하나만 고를 수 있어요." % label["ko"], "en": "Pick only one for '%s'." % label["en"]})
		if slot.get("multi", false) and slot.has("max") and chosen.size() > int(slot["max"]):
			notes.append({"ko": "'%s'은 최대 %d개까지예요." % [label["ko"], int(slot["max"])], "en": "'%s' takes at most %d." % [label["en"], int(slot["max"])]})
		for id in chosen:
			if option(spec, slot["id"], id).is_empty():
				notes.append(t("알 수 없는 선택이 있어요.", "Unknown option."))
	return notes
