class_name SkyCycle
extends RefCounted
## The authored surface-lighting curve shared by every outdoor scene.
##
## The clock owns time; this value object owns what that time looks like. Keeping
## the palette here means garrisons can compose their own atmosphere without
## copying or gradually drifting away from the canonical sunrise and sunset.

const FALLBACK_SUNRISE_HOUR: float = 5.0
const FALLBACK_SUNSET_HOUR: float = 20.0

# Colours are intentionally bright in source space. The sky shader declares its
# colour uniforms as `source_color`, so Godot decodes them to linear space.
const KEYS: Array[Dictionary] = [
	{"h": 0.0, "top": Color(0.015, 0.02, 0.05), "hor": Color(0.03, 0.04, 0.09), "sun_e": 0.0, "amb": 0.08, "suncol": Color(0.45, 0.52, 0.80), "curve": 0.15, "night": 1.0},
	{"h": 3.75, "top": Color(0.12, 0.10, 0.24), "hor": Color(0.54, 0.30, 0.22), "sun_e": 0.04, "amb": 0.07, "suncol": Color(0.95, 0.62, 0.38), "curve": 0.34, "night": 0.78},
	{"h": 5.0, "top": Color(0.46, 0.36, 0.56), "hor": Color(1.00, 0.62, 0.36), "sun_e": 0.58, "amb": 0.18, "suncol": Color(1.00, 0.66, 0.42), "curve": 0.47, "night": 0.12, "beat": &"sunrise"},
	{"h": 6.25, "top": Color(0.45, 0.57, 0.74), "hor": Color(0.78, 0.76, 0.72), "sun_e": 0.94, "amb": 0.34, "suncol": Color(0.99, 0.84, 0.66), "curve": 0.24, "night": 0.0},
	{"h": 8.0, "top": Color(0.46, 0.58, 0.74), "hor": Color(0.72, 0.74, 0.78), "sun_e": 1.02, "amb": 0.38, "suncol": Color(0.96, 0.86, 0.72), "curve": 0.22, "night": 0.0},
	{"h": 12.5, "top": Color(0.40, 0.55, 0.80), "hor": Color(0.64, 0.74, 0.85), "sun_e": 1.16, "amb": 0.42, "suncol": Color(0.98, 0.94, 0.84), "curve": 0.15, "night": 0.0},
	{"h": 17.5, "top": Color(0.44, 0.56, 0.76), "hor": Color(0.70, 0.74, 0.80), "sun_e": 1.08, "amb": 0.40, "suncol": Color(0.99, 0.88, 0.72), "curve": 0.18, "night": 0.0},
	{"h": 18.75, "top": Color(0.45, 0.53, 0.68), "hor": Color(0.82, 0.72, 0.60), "sun_e": 0.94, "amb": 0.32, "suncol": Color(1.00, 0.80, 0.56), "curve": 0.28, "night": 0.0},
	{"h": 20.0, "top": Color(0.44, 0.32, 0.54), "hor": Color(1.00, 0.52, 0.28), "sun_e": 0.58, "amb": 0.18, "suncol": Color(1.00, 0.54, 0.30), "curve": 0.48, "night": 0.12, "beat": &"sunset"},
	{"h": 21.25, "top": Color(0.12, 0.10, 0.24), "hor": Color(0.58, 0.32, 0.22), "sun_e": 0.05, "amb": 0.07, "suncol": Color(0.95, 0.60, 0.36), "curve": 0.34, "night": 0.78},
	{"h": 24.0, "top": Color(0.015, 0.02, 0.05), "hor": Color(0.03, 0.04, 0.09), "sun_e": 0.0, "amb": 0.08, "suncol": Color(0.45, 0.52, 0.80), "curve": 0.15, "night": 1.0},
]


static func sunrise_hour() -> float:
	for key: Dictionary in KEYS:
		if StringName(key.get("beat", &"")) == &"sunrise":
			return float(key["h"])
	push_error("[SkyCycle] Missing sunrise beat; using fallback.")
	return FALLBACK_SUNRISE_HOUR


static func sunset_hour() -> float:
	for key: Dictionary in KEYS:
		if StringName(key.get("beat", &"")) == &"sunset":
			return float(key["h"])
	push_error("[SkyCycle] Missing sunset beat; using fallback.")
	return FALLBACK_SUNSET_HOUR


static func is_daylight(h: float) -> bool:
	var normalized_hour: float = fposmod(h, 24.0)
	return normalized_hour >= sunrise_hour() and normalized_hour < sunset_hour()


static func phase_of(h: float) -> StringName:
	var normalized_hour: float = fposmod(h, 24.0)
	var sunrise: float = sunrise_hour()
	var sunset: float = sunset_hour()
	if normalized_hour >= sunrise - 1.0 and normalized_hour < sunrise:
		return &"dawn"
	if normalized_hour >= sunrise and normalized_hour < sunset:
		return &"day"
	if normalized_hour >= sunset and normalized_hour < sunset + 1.0:
		return &"dusk"
	return &"night"


static func hour_string(h: float) -> String:
	var total_minutes: int = int(floor(fposmod(h, 24.0) * 60.0 + 0.0001)) % 1440
	var hour_24: int = int(floor(float(total_minutes) / 60.0))
	var minute: int = total_minutes % 60
	var suffix: String = "am" if hour_24 < 12 else "pm"
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d%s" % [hour_12, minute, suffix]


static func sample(h: float) -> Dictionary:
	var normalized_hour: float = fposmod(h, 24.0)
	var first: Dictionary = KEYS[0]
	var second: Dictionary = KEYS[KEYS.size() - 1]
	for i: int in range(KEYS.size() - 1):
		var candidate: Dictionary = KEYS[i + 1]
		if normalized_hour <= float(candidate["h"]):
			first = KEYS[i]
			second = candidate
			break
	var span: float = maxf(0.0001, float(second["h"]) - float(first["h"]))
	var weight: float = clampf((normalized_hour - float(first["h"])) / span, 0.0, 1.0)
	return {
		"top": Color(first["top"]).lerp(Color(second["top"]), weight),
		"hor": Color(first["hor"]).lerp(Color(second["hor"]), weight),
		"sun_e": lerpf(float(first["sun_e"]), float(second["sun_e"]), weight),
		"amb": lerpf(float(first["amb"]), float(second["amb"]), weight),
		"suncol": Color(first["suncol"]).lerp(Color(second["suncol"]), weight),
		"curve": lerpf(float(first["curve"]), float(second["curve"]), weight),
		"night": lerpf(float(first["night"]), float(second["night"]), weight),
	}
