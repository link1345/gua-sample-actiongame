class_name MissionState
extends RefCounted

signal changed
signal message_added(sender: String, text: String)
signal mission_finished(success: bool)

const MAX_HP := 100

var hp := MAX_HP
var shield_enabled := false
var reactor_power := 30.0
var power_route := 0
var door_a_open := false
var exit_unlocked := false
var at_door_a := false
var past_door_a := false
var in_laser_corridor := false
var at_exit := false
var mission_complete := false
var mission_failed := false
var laser_suppressed_until := 0.0
var latest_agent_message := "Control link established. Move to Door A and report when ready."
var latest_human_reply := "No response yet"
var message_history: Array[String] = []
var elapsed := 0.0


func reset() -> void:
	hp = MAX_HP
	shield_enabled = false
	reactor_power = 30.0
	power_route = 0
	door_a_open = false
	exit_unlocked = false
	at_door_a = false
	past_door_a = false
	in_laser_corridor = false
	at_exit = false
	mission_complete = false
	mission_failed = false
	laser_suppressed_until = 0.0
	latest_agent_message = "Control link established. Move to Door A and report when ready."
	latest_human_reply = "No response yet"
	message_history.clear()
	elapsed = 0.0
	append_message("CONTROL", latest_agent_message)
	changed.emit()


func tick(delta: float) -> void:
	if mission_complete or mission_failed:
		return
	elapsed += delta


func set_shield(value: bool) -> void:
	if shield_enabled == value or mission_complete or mission_failed:
		return
	shield_enabled = value
	append_message("SYSTEM", "Field shield enabled." if value else "Field shield disabled.")
	changed.emit()


func set_power(value: float) -> void:
	if mission_complete or mission_failed:
		return
	var previous := reactor_power
	reactor_power = clampf(value, 0.0, 100.0)
	if previous <= 80.0 and reactor_power > 80.0 and not shield_enabled:
		damage(34, "Unshielded reactor surge")
	changed.emit()


func set_route(index: int) -> void:
	if mission_complete or mission_failed:
		return
	power_route = clampi(index, 0, 1)
	if power_route == 1:
		laser_suppressed_until = elapsed + 6.0
		append_message("SYSTEM", "Maintenance route active. Laser paused for 6 seconds.")
	else:
		append_message("SYSTEM", "Power returned to primary systems.")
	changed.emit()


func try_open_door_a() -> bool:
	if door_a_open or mission_complete or mission_failed:
		return door_a_open
	if reactor_power <= 80.0:
		append_message("SYSTEM", "Door A denied: reactor power must exceed 80%.")
		changed.emit()
		return false
	door_a_open = true
	append_message("SYSTEM", "Door A unlocked. Passage is open.")
	changed.emit()
	return true


func try_unlock_exit() -> bool:
	if exit_unlocked or mission_complete or mission_failed:
		return exit_unlocked
	if not at_exit:
		append_message("SYSTEM", "Exit denied: field operator is not at the extraction zone.")
		changed.emit()
		return false
	exit_unlocked = true
	append_message("CONTROL", "Exit lock released. Step into the airlock!")
	changed.emit()
	return true


func laser_is_active() -> bool:
	return not mission_complete and not mission_failed and elapsed >= laser_suppressed_until


func damage(amount: int, reason: String) -> void:
	if mission_complete or mission_failed:
		return
	hp = maxi(0, hp - amount)
	append_message("WARNING", "%s. Operator HP: %d%%" % [reason, hp])
	if hp == 0:
		mission_failed = true
		append_message("SYSTEM", "MISSION FAILED — field operator signal lost.")
		mission_finished.emit(false)
	changed.emit()


func send_agent_message(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty() or mission_complete or mission_failed:
		return false
	latest_agent_message = clean.left(180)
	append_message("CONTROL", latest_agent_message)
	changed.emit()
	return true


func send_human_reply(text: String) -> void:
	if mission_complete or mission_failed:
		return
	latest_human_reply = text
	append_message("FIELD", text)
	changed.emit()


func complete() -> void:
	if mission_complete or mission_failed:
		return
	mission_complete = true
	append_message("SYSTEM", "MISSION COMPLETE — Sector A evacuated in %s." % format_time())
	mission_finished.emit(true)
	changed.emit()


func append_message(sender: String, text: String) -> void:
	var entry := "%s  %s" % [sender, text]
	message_history.push_back(entry)
	if message_history.size() > 8:
		message_history.pop_front()
	message_added.emit(sender, text)


func objective() -> String:
	if mission_complete:
		return "Mission complete — Sector A evacuated"
	if mission_failed:
		return "Mission failed — restart the operation"
	if not at_door_a:
		return "Reach Door A and establish contact"
	if not door_a_open:
		return "Control: shield, route >80% power, then open Door A"
	if not past_door_a:
		return "Pass through Door A"
	if not at_exit:
		return "Control: select Maintenance; Field: cross the laser corridor"
	if not exit_unlocked:
		return "Control: release the exit lock"
	return "Field: enter the extraction airlock"


func location_name() -> String:
	if at_exit:
		return "Extraction zone"
	if in_laser_corridor:
		return "Laser corridor"
	if past_door_a:
		return "Sector A interior"
	if at_door_a:
		return "Door A checkpoint"
	return "Arrival bay"


func format_time() -> String:
	var seconds := int(elapsed)
	return "%02d:%02d" % [seconds / 60, seconds % 60]

