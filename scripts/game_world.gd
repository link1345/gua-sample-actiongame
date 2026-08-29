class_name SignalRelayWorld
extends Control

const GameTextScript := preload("res://scripts/game_text.gd")

signal world_state_changed

const WORLD_SIZE := Vector2(820, 480)
const PLAYER_RADIUS := 13.0
const DOOR_X := 335.0
const EXIT_X := 770.0
const LASER_X := 560.0
const COLORS := {
	"background": Color("07131d"),
	"grid": Color("142d3a"),
	"wall": Color("294353"),
	"cyan": Color("43e5ff"),
	"amber": Color("ffba5c"),
	"red": Color("ff526d"),
	"green": Color("68f7a1"),
}

var state: MissionState
var player_position := Vector2(92, 320)
var velocity := Vector2.ZERO
var hit_cooldown := 0.0
var intro_pulse := 0.0
var active := false


func setup(mission_state: MissionState) -> void:
	state = mission_state
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_active(false)
	reset_player()


func set_active(value: bool) -> void:
	active = value
	set_process(value)
	set_process_unhandled_input(value)


func reset_player() -> void:
	player_position = Vector2(92, 320)
	velocity = Vector2.ZERO
	hit_cooldown = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if state == null or not active:
		return
	state.tick(delta)
	intro_pulse += delta
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	if not state.mission_complete and not state.mission_failed:
		_move_player(delta)
		_update_zones()
		_update_hazard()
	queue_redraw()


func _move_player(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input * 190.0
	var next := player_position + velocity * delta
	next.x = clampf(next.x, 32.0, WORLD_SIZE.x - 32.0)
	next.y = clampf(next.y, 92.0, WORLD_SIZE.y - 30.0)

	# Door A blocks the central passage until Control opens it.
	if not state.door_a_open and player_position.x < DOOR_X and next.x + PLAYER_RADIUS >= DOOR_X:
		next.x = DOOR_X - PLAYER_RADIUS
	if not state.door_a_open and player_position.x > DOOR_X and next.x - PLAYER_RADIUS <= DOOR_X:
		next.x = DOOR_X + PLAYER_RADIUS

	# The locked exit remains a physical boundary.
	if not state.exit_unlocked and player_position.x < EXIT_X and next.x + PLAYER_RADIUS >= EXIT_X:
		next.x = EXIT_X - PLAYER_RADIUS
	player_position = next

	if state.exit_unlocked and player_position.x >= EXIT_X:
		state.complete()


func _update_zones() -> void:
	var old := [state.at_door_a, state.past_door_a, state.in_laser_corridor, state.at_exit]
	state.at_door_a = player_position.x >= 275.0 and player_position.x <= 345.0
	state.past_door_a = player_position.x > 360.0
	state.in_laser_corridor = player_position.x >= 490.0 and player_position.x <= 625.0
	state.at_exit = player_position.x >= 700.0 and player_position.x < EXIT_X
	var current := [state.at_door_a, state.past_door_a, state.in_laser_corridor, state.at_exit]
	if old != current:
		state.changed.emit()
		world_state_changed.emit()


func _update_hazard() -> void:
	if not state.laser_is_active() or not state.in_laser_corridor or hit_cooldown > 0.0:
		return
	if absf(player_position.x - LASER_X) < 22.0:
		hit_cooldown = 1.0
		state.damage(28, "laser")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), COLORS.background)
	for x in range(0, int(WORLD_SIZE.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), COLORS.grid, 1.0)
	for y in range(0, int(WORLD_SIZE.y), 40):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), COLORS.grid, 1.0)

	# Station walls and the playable corridor.
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 74), COLORS.wall)
	draw_rect(Rect2(0, WORLD_SIZE.y - 18, WORLD_SIZE.x, 18), COLORS.wall)
	draw_string(get_theme_default_font(), Vector2(24, 45), _text("world_field_feed"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("82aabb"))
	draw_string(get_theme_default_font(), Vector2(650, 45), _text("world_live", [state.format_time()]) if state else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COLORS.green)

	_draw_zone(Rect2(42, 105, 225, 330), _text("world_arrival"), Color("173240"))
	_draw_zone(Rect2(368, 105, 105, 330), _text("world_sector"), Color("152b36"))
	_draw_zone(Rect2(486, 105, 148, 330), _text("world_laser"), Color("351b2b"))
	_draw_zone(Rect2(650, 105, 125, 330), _text("world_extraction"), Color("163328"))

	_draw_door(DOOR_X, _text("world_door"), state != null and state.door_a_open)
	_draw_door(EXIT_X, _text("world_exit"), state != null and state.exit_unlocked)
	_draw_laser()
	_draw_player()


func _draw_zone(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color(color, 0.9), false, 2.0)
	draw_string(get_theme_default_font(), rect.position + Vector2(12, 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6f94a4"))


func _draw_door(x: float, label: String, open: bool) -> void:
	var color := COLORS.green if open else COLORS.amber
	if not open:
		draw_rect(Rect2(x - 7, 90, 14, 365), color)
		draw_line(Vector2(x - 18, 90), Vector2(x + 18, 90), Color.WHITE, 2.0)
	else:
		draw_rect(Rect2(x - 8, 90, 16, 75), color)
		draw_rect(Rect2(x - 8, 380, 16, 75), color)
	draw_string(get_theme_default_font(), Vector2(x - 55, 84), "%s %s" % [label, _text("state_open") if open else _text("state_locked")], HORIZONTAL_ALIGNMENT_CENTER, 110, 12, color)


func _draw_laser() -> void:
	if state == null:
		return
	var active := state.laser_is_active()
	var laser_color := COLORS.red if active else Color("46606b")
	for offset in [-30.0, 0.0, 30.0]:
		var width := 4.0 + sin(intro_pulse * 8.0 + offset) if active else 2.0
		draw_line(Vector2(LASER_X + offset, 120), Vector2(LASER_X + offset, 425), laser_color, width)
	draw_string(get_theme_default_font(), Vector2(505, 455), _text("state_active") if active else _text("state_suppressed"), HORIZONTAL_ALIGNMENT_CENTER, 110, 13, laser_color)


func _draw_player() -> void:
	if state == null:
		return
	var shield_color := Color(COLORS.cyan, 0.22 + sin(intro_pulse * 5.0) * 0.06)
	if state.shield_enabled:
		draw_circle(player_position, 23.0, shield_color)
		draw_arc(player_position, 23.0, 0, TAU, 40, COLORS.cyan, 2.0)
	var body_color := COLORS.red if hit_cooldown > 0.0 else Color("e9f7ff")
	draw_circle(player_position, PLAYER_RADIUS, body_color)
	draw_circle(player_position, 6.0, COLORS.cyan)
	draw_string(get_theme_default_font(), player_position + Vector2(-26, -22), _text("world_field"), HORIZONTAL_ALIGNMENT_CENTER, 52, 11, Color("d8f7ff"))


func _text(key: String, values: Array = []) -> String:
	return GameTextScript.text(state.locale if state != null else GameTextScript.JA, key, values)
