class_name MissionState
extends RefCounted

signal changed
signal message_added(sender: String, text: String)
signal mission_finished(success: bool)

const GameTextScript := preload("res://scripts/game_text.gd")
const MAX_HP := 100
const PIXELS_PER_METER := 10.0
const DOOR_TARGET_X := 335.0
const LASER_STAGING_TARGET_X := 470.0
const EXTRACTION_TARGET_X := 720.0
const AIRLOCK_TARGET_X := 770.0

var locale := GameTextScript.JA
var hp := MAX_HP
var shield_enabled := false
var reactor_power := 30.0
var door_a_open := false
var exit_unlocked := false
var at_door_a := false
var past_door_a := false
var at_laser_staging := false
var in_laser_corridor := false
var past_laser := false
var at_exit := false
var mission_complete := false
var mission_failed := false
var laser_suppressed_until := 0.0
var laser_suppression_started_at := -1.0
var laser_suppression_activation_id := 0
var operator_x := 92.0
var latest_agent_message := ""
var latest_agent_message_is_default := true
var latest_human_message := ""
var message_history: Array[Dictionary] = []
var elapsed := 0.0


func reset() -> void:
	hp = MAX_HP
	shield_enabled = false
	reactor_power = 30.0
	door_a_open = false
	exit_unlocked = false
	at_door_a = false
	past_door_a = false
	at_laser_staging = false
	in_laser_corridor = false
	past_laser = false
	at_exit = false
	mission_complete = false
	mission_failed = false
	laser_suppressed_until = 0.0
	laser_suppression_started_at = -1.0
	laser_suppression_activation_id = 0
	operator_x = 92.0
	latest_agent_message_is_default = true
	latest_agent_message = _text("message_initial")
	latest_human_message = ""
	message_history.clear()
	elapsed = 0.0
	append_localized_message("control", "message_initial")
	changed.emit()


func set_locale(value: String) -> void:
	if value == locale:
		return
	locale = value
	if latest_agent_message_is_default:
		latest_agent_message = _text("message_initial")
	changed.emit()


func tick(delta: float) -> void:
	if mission_complete or mission_failed:
		return
	elapsed += delta


func can_open_door_a() -> bool:
	return not door_a_open and not mission_complete and not mission_failed and shield_enabled and reactor_power > 80.0


func can_unlock_exit() -> bool:
	return not exit_unlocked and not mission_complete and not mission_failed and at_exit


func can_suppress_laser() -> bool:
	return door_a_open and (at_laser_staging or in_laser_corridor) and not mission_complete and not mission_failed and laser_is_active()


func set_shield(value: bool) -> void:
	if shield_enabled == value or mission_complete or mission_failed:
		return
	shield_enabled = value
	append_localized_message("system", "message_shield_on" if value else "message_shield_off")
	changed.emit()


func set_power(value: float) -> void:
	if mission_complete or mission_failed:
		return
	var previous := reactor_power
	reactor_power = clampf(value, 0.0, 100.0)
	if previous <= 80.0 and reactor_power > 80.0 and not shield_enabled:
		damage(34, "reactor")
	changed.emit()


func suppress_laser() -> bool:
	if not can_suppress_laser():
		return false
	laser_suppression_started_at = elapsed
	laser_suppressed_until = laser_suppression_started_at + 6.0
	laser_suppression_activation_id += 1
	append_localized_message("system", "message_laser_suppressed")
	changed.emit()
	return true


func try_open_door_a() -> bool:
	if door_a_open or mission_complete or mission_failed:
		return door_a_open
	if not shield_enabled:
		append_localized_message("system", "message_door_need_shield")
		changed.emit()
		return false
	if reactor_power <= 80.0:
		append_localized_message("system", "message_door_need_current")
		changed.emit()
		return false
	door_a_open = true
	append_localized_message("system", "message_door_open")
	changed.emit()
	return true


func try_unlock_exit() -> bool:
	if exit_unlocked or mission_complete or mission_failed:
		return exit_unlocked
	if not at_exit:
		append_localized_message("system", "message_exit_denied")
		changed.emit()
		return false
	exit_unlocked = true
	append_localized_message("control", "message_exit_open")
	changed.emit()
	return true


func laser_remaining_seconds() -> float:
	return maxf(0.0, laser_suppressed_until - elapsed)


func laser_is_active() -> bool:
	return not mission_complete and not mission_failed and laser_remaining_seconds() <= 0.0


func laser_suppression_state_key() -> String:
	return "active" if laser_is_active() else "suppressed"


func laser_started_at_text() -> String:
	return _format_tenths(laser_suppression_started_at) if laser_suppression_started_at >= 0.0 else _text("timing_not_started")


func laser_ends_at_text() -> String:
	return _format_tenths(laser_suppressed_until) if laser_suppression_started_at >= 0.0 else _text("timing_not_started")


func update_operator_position(value: float) -> bool:
	var rounded_value := snappedf(value, 0.1)
	if is_equal_approx(operator_x, rounded_value):
		return false
	operator_x = rounded_value
	return true


func operator_position_meters() -> float:
	return snappedf(operator_x / PIXELS_PER_METER, 0.1)


func next_target_key() -> String:
	if mission_complete or exit_unlocked or at_exit:
		return "world_airlock"
	if past_laser:
		return "world_extraction"
	if door_a_open and (past_door_a or at_laser_staging or in_laser_corridor):
		return "world_staging" if not at_laser_staging and not in_laser_corridor else "world_extraction"
	return "world_door"


func next_target_x() -> float:
	match next_target_key():
		"world_staging": return LASER_STAGING_TARGET_X
		"world_extraction": return EXTRACTION_TARGET_X
		"world_airlock": return AIRLOCK_TARGET_X
		_: return DOOR_TARGET_X


func next_target_distance_meters() -> float:
	return snappedf(absf(next_target_x() - operator_x) / PIXELS_PER_METER, 0.1)


func next_direction_key() -> String:
	var delta := next_target_x() - operator_x
	if absf(delta) <= PIXELS_PER_METER * 0.5:
		return "direction_arrived"
	return "direction_east" if delta > 0.0 else "direction_west"


func zone_key() -> String:
	if mission_complete or operator_x >= AIRLOCK_TARGET_X:
		return "airlock"
	if at_exit:
		return "extraction_zone"
	if past_laser:
		return "post_laser"
	if in_laser_corridor:
		return "laser_corridor"
	if at_laser_staging:
		return "laser_staging"
	if past_door_a:
		return "sector_a"
	if at_door_a:
		return "door_a"
	return "arrival_bay"


func damage(amount: int, reason: String) -> void:
	if mission_complete or mission_failed:
		return
	hp = maxi(0, hp - amount)
	append_localized_message("warning", "message_damage_laser" if reason == "laser" else "message_damage_reactor", [hp])
	if hp == 0:
		mission_failed = true
		append_localized_message("system", "message_failed")
		mission_finished.emit(false)
	changed.emit()


func send_agent_message(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty() or mission_complete or mission_failed:
		return false
	latest_agent_message = clean.left(180)
	latest_agent_message_is_default = false
	append_literal_message("control", latest_agent_message)
	changed.emit()
	return true


func send_human_message(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty() or mission_complete or mission_failed:
		return false
	latest_human_message = clean.left(180)
	append_literal_message("field", latest_human_message)
	changed.emit()
	return true


func complete() -> void:
	if mission_complete or mission_failed:
		return
	mission_complete = true
	at_exit = true
	append_localized_message("system", "message_complete", [format_time()])
	mission_finished.emit(true)
	changed.emit()


func append_localized_message(sender_key: String, text_key: String, values: Array = []) -> void:
	message_history.push_back({"sender_key": sender_key, "text_key": text_key, "values": values.duplicate(true)})
	_trim_messages()
	message_added.emit(_text("sender_" + sender_key), _text(text_key, values))


func append_literal_message(sender_key: String, value: String) -> void:
	message_history.push_back({"sender_key": sender_key, "literal": value})
	_trim_messages()
	message_added.emit(_text("sender_" + sender_key), value)


func rendered_message_history() -> Array[String]:
	var result: Array[String] = []
	for entry in message_history:
		var sender := _text("sender_" + str(entry.get("sender_key", "system")))
		var body := str(entry.get("literal", "")) if entry.has("literal") else _text(str(entry.get("text_key", "")), entry.get("values", []))
		result.push_back("%s  %s" % [sender, body])
	return result


func objective() -> String:
	if mission_complete:
		return _text("objective_complete")
	if mission_failed:
		return _text("objective_failed")
	if exit_unlocked:
		return _text("objective_enter_airlock")
	if at_exit:
		return _text("objective_release_exit")
	if past_laser:
		return _text("objective_reach_exit")
	if in_laser_corridor:
		return _text("objective_cross_laser")
	if at_laser_staging:
		return _text("objective_ai_suppress_laser") if laser_is_active() else _text("objective_cross_laser")
	if past_door_a:
		return _text("objective_reach_laser_staging")
	if door_a_open:
		return _text("objective_pass_door")
	if at_door_a:
		return _text("objective_prepare_door")
	return _text("objective_reach_door")


func location_name() -> String:
	if mission_complete:
		return _text("location_evacuated")
	if at_exit:
		return _text("location_exit")
	if past_laser:
		return _text("location_post_laser")
	if in_laser_corridor:
		return _text("location_laser")
	if at_laser_staging:
		return _text("location_laser_staging")
	if past_door_a:
		return _text("location_interior")
	if at_door_a:
		return _text("location_door")
	return _text("location_arrival")


func format_time() -> String:
	var seconds := int(elapsed)
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _format_tenths(value: float) -> String:
	var tenths := int(round(value * 10.0))
	return "%02d:%02d.%d" % [(tenths / 10) / 60, (tenths / 10) % 60, tenths % 10]


func _trim_messages() -> void:
	if message_history.size() > 8:
		message_history.pop_front()


func _text(key: String, values: Array = []) -> String:
	return GameTextScript.text(locale, key, values)
