class_name Divisions
extends RefCounted
## The weight divisions. Every boxer belongs to one, and fights are always
## between two boxers from the same division.
##
##   height_cm / weight_lb  - ranges used when generating a boxer
##   roster_seed            - the starting roster is the same every run
##   power_scale            - damage multiplier (heavier = harder punches)
##   speed_scale            - action time multiplier (> 1 = slower)
##   ko_bias                - nudges the made-up record's knockout rate
##
## Body shape on screen comes from height and weight (see
## BoxerSkeleton.build_for), so a heavyweight is drawn bigger and thicker and
## a lightweight smaller and wiry without any division-specific art.

enum Id { LIGHTWEIGHT, MIDDLEWEIGHT, HEAVYWEIGHT }

const LIST: Array = [
	{"name": "Lightweight",  "height_cm": [165, 178], "weight_lb": [130, 136], "roster_seed": 1983, "power_scale": 0.90, "speed_scale": 0.92, "ko_bias": -0.08},
	{"name": "Middleweight", "height_cm": [170, 198], "weight_lb": [154, 160], "roster_seed": 1985, "power_scale": 1.00, "speed_scale": 1.00, "ko_bias":  0.00},
	{"name": "Heavyweight",  "height_cm": [185, 204], "weight_lb": [200, 290], "roster_seed": 1989, "power_scale": 1.25, "speed_scale": 1.10, "ko_bias":  0.12},
]


static func count() -> int:
	return LIST.size()


static func get_division(id: int) -> Dictionary:
	return LIST[clampi(id, 0, LIST.size() - 1)]


static func division_name(id: int) -> String:
	return get_division(id)["name"]
