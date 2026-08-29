extends Control

const GuaAutoAdapterScript := preload("res://addons/gua/gua_auto_adapter.gd")
const MissionStateScript := preload("res://scripts/mission_state.gd")
const WorldScript := preload("res://scripts/game_world.gd")
const GameTextScript := preload("res://scripts/game_text.gd")
const DisplayFont := preload("res://assets/fonts/MPLUS1p-Regular.ttf")

const BG := Color("050b12")
const PANEL := Color("0d1b25")
const PANEL_2 := Color("122733")
const CYAN := Color("43e5ff")
const GREEN := Color("68f7a1")
const AMBER := Color("ffba5c")
const RED := Color("ff526d")
const TEXT := Color("d8edf4")
const MUTED := Color("7897a5")

var state := MissionStateScript.new()
var locale := GameTextScript.JA
var game_started := false
var ui
var world: SignalRelayWorld
var title_screen: Control
var mission_screen: Control
var language_toggle: Button
var play_game_button: Button
var objective_label: Label
var hp_label: Label
var location_label: Label
var shield_status_label: Label
var door_status_label: Label
var laser_status_label: Label
var next_target_label: Label
var next_direction_label: Label
var next_distance_label: Label
var laser_staging_ready_label: Label
var laser_timing_state_label: Label
var laser_started_at_label: Label
var laser_ends_at_label: Label
var laser_activation_id_label: Label
var power_value_label: Label
var current_readout_label: Label
var status_container: VBoxContainer
var power_slider: HSlider
var shield_check: CheckBox
var door_button: Button
var exit_button: Button
var suppress_laser_button: Button
var laser_remaining: ProgressBar
var message_draft: LineEdit
var human_message_draft: LineEdit
var history_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_text: Label
var return_title_button: Button


func _ready() -> void:
	set_meta("gua_id", "game-root")
	set_meta("gua_agent_exposure", "auto")
	_build_theme()
	_build_interface()
	state.changed.connect(_sync_ui)
	state.mission_finished.connect(_show_result)
	state.reset()
	_setup_gua()
	_show_title()


func _exit_tree() -> void:
	if ui != null and ui.has_method("dispose"):
		ui.dispose()


func _process(_delta: float) -> void:
	if game_started:
		_sync_live_ui()
		world.queue_redraw()
	if ui != null:
		ui.update(_screen_name())


func _screen_name() -> String:
	if not game_started:
		return "title"
	if state.mission_complete:
		return "mission-complete"
	if state.mission_failed:
		return "mission-failed"
	return "mission"


func _setup_gua() -> void:
	if not ResourceLoader.exists("res://addons/gua/gua_auto_adapter.gd"):
		push_warning("Gua v1.0.2 addon is not installed. Run scripts/install-gua.ps1 before testing WebMCP.")
		return
	ui = GuaAutoAdapterScript.new()
	ui.attach(self)
	if not OS.has_feature("web"):
		var bridge_port := _resolve_gua_bridge_port()
		if bridge_port <= 0:
			return
		if ui.start_inspector_bridge(bridge_port):
			print("Gua test bridge listening at %s" % ui.inspector_bridge_url())
		else:
			push_warning("Could not start the Gua test bridge on port %d." % bridge_port)


func _resolve_gua_bridge_port() -> int:
	var configured_port := OS.get_environment("GUA_BRIDGE_PORT")
	if configured_port.is_valid_int():
		var parsed_port := configured_port.to_int()
		if parsed_port > 0 and parsed_port <= 65535:
			return parsed_port
	return 0


func _build_theme() -> void:
	var game_theme := Theme.new()
	game_theme.default_font = DisplayFont
	game_theme.default_font_size = 15
	game_theme.set_color("font_color", "Label", TEXT)
	game_theme.set_color("font_color", "Button", TEXT)
	game_theme.set_color("font_hover_color", "Button", Color.WHITE)
	game_theme.set_color("font_pressed_color", "Button", BG)
	game_theme.set_color("font_color", "CheckBox", TEXT)
	game_theme.set_color("font_color", "LineEdit", TEXT)
	game_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	game_theme.set_stylebox("normal", "Button", _box(PANEL_2, Color("2c5364"), 6))
	game_theme.set_stylebox("hover", "Button", _box(Color("173b4b"), CYAN, 6))
	game_theme.set_stylebox("pressed", "Button", _box(CYAN, CYAN, 6))
	game_theme.set_stylebox("disabled", "Button", _box(Color("111c23"), Color("293a43"), 6))
	game_theme.set_stylebox("normal", "LineEdit", _box(Color("07131d"), Color("2b5363"), 5))
	game_theme.set_stylebox("focus", "LineEdit", _box(Color("07131d"), CYAN, 5))
	game_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("1c3b49"), 8))
	game_theme.set_stylebox("slider", "HSlider", _flat(Color("25414d")))
	game_theme.set_stylebox("grabber_area", "HSlider", _flat(CYAN))
	game_theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color.WHITE))
	theme = game_theme


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_build_title_screen()
	mission_screen = Control.new()
	mission_screen.name = "MissionScreen"
	_public(mission_screen, "mission-screen", [])
	mission_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mission_screen)
	_build_mission_screen()
	language_toggle = Button.new()
	language_toggle.name = "LanguageToggle"
	_private(language_toggle, "language-toggle")
	language_toggle.position = Vector2(1142, 22)
	language_toggle.size = Vector2(106, 36)
	language_toggle.pressed.connect(_toggle_locale)
	add_child(language_toggle)
	_sync_language_toggle()


func _build_title_screen() -> void:
	title_screen = Control.new()
	title_screen.name = "TitleScreen"
	_public(title_screen, "title-screen", [])
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)
	var glow := ColorRect.new()
	glow.color = Color("091824")
	glow.position = Vector2(120, 70)
	glow.size = Vector2(1040, 620)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(glow)
	var title := _localized_label("title-heading", "app_title", 42, CYAN)
	title.position = Vector2(170, 110)
	title.size = Vector2(940, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_screen.add_child(title)
	var subtitle := _localized_label("title-subtitle", "mission_subtitle", 19, MUTED)
	subtitle.position = Vector2(170, 170)
	subtitle.size = Vector2(940, 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_screen.add_child(subtitle)
	title_screen.add_child(_title_copy("title-game-description", "title_game_description", 235, 19, TEXT))
	title_screen.add_child(_title_copy("title-goal", "title_goal", 285, 17, CYAN))
	title_screen.add_child(_title_copy("title-human-role", "title_human_role", 350, 16, TEXT))
	title_screen.add_child(_title_copy("title-ai-role", "title_ai_role", 405, 16, TEXT))
	play_game_button = Button.new()
	play_game_button.name = "PlayGame"
	_public(play_game_button, "play-game", ["click"])
	_localized(play_game_button, "play_game")
	play_game_button.position = Vector2(470, 505)
	play_game_button.size = Vector2(340, 62)
	play_game_button.add_theme_font_size_override("font_size", 21)
	play_game_button.pressed.connect(_start_game)
	title_screen.add_child(play_game_button)
	_disable_human_input(play_game_button)
	var restriction := _title_copy("title-start-restriction", "title_start_restriction", 585, 15, AMBER)
	restriction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_screen.add_child(restriction)


func _title_copy(id: String, key: String, y: float, font_size: int, color: Color) -> Label:
	var label := _localized_label(id, key, font_size, color)
	label.position = Vector2(230, y)
	label.size = Vector2(820, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_mission_screen() -> void:
	var header := ColorRect.new()
	header.color = Color("091824")
	header.position = Vector2(18, 16)
	header.size = Vector2(1244, 62)
	mission_screen.add_child(header)
	var title := _localized_label("mission-title", "app_title", 20, CYAN)
	title.position = Vector2(38, 26)
	title.size = Vector2(320, 28)
	mission_screen.add_child(title)
	var subtitle := _localized_label("mission-subtitle", "mission_subtitle", 12, MUTED)
	subtitle.position = Vector2(40, 53)
	subtitle.size = Vector2(300, 18)
	mission_screen.add_child(subtitle)
	objective_label = _label("current-objective", "", 18, TEXT)
	objective_label.position = Vector2(372, 27)
	objective_label.size = Vector2(580, 42)
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mission_screen.add_child(objective_label)
	hp_label = _label("operator-hp", "HP 100%", 20, GREEN)
	hp_label.position = Vector2(1010, 28)
	hp_label.size = Vector2(120, 34)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_screen.add_child(hp_label)
	world = WorldScript.new()
	world.name = "FieldView"
	_public(world, "field-world-view", [])
	world.position = Vector2(18, 92)
	world.size = Vector2(820, 480)
	mission_screen.add_child(world)
	world.setup(state)
	_build_console()
	_build_human_current_readout()
	_build_terminal()
	_build_result_overlay()


func _build_console() -> void:
	var panel := PanelContainer.new()
	panel.name = "ControlConsole"
	_public(panel, "control-console", [])
	panel.position = Vector2(854, 92)
	panel.size = Vector2(408, 480)
	mission_screen.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	column.add_child(_localized_label("console-title", "console_title", 18, CYAN))
	column.add_child(_localized_label("console-link-status", "console_link", 10, GREEN))
	column.add_child(_separator())
	var warning_box := VBoxContainer.new()
	_public(warning_box, "power-warning", [])
	column.add_child(warning_box)
	warning_box.add_child(_localized_label("power-warning-title", "warning_title", 13, AMBER))
	var warning := _localized_label("power-warning-description", "warning_description", 11, TEXT)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 31
	warning_box.add_child(warning)
	var reactor_rules := _localized_label("reactor-hazard-rules", "reactor_hazard_rules", 9, AMBER)
	reactor_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_box.add_child(reactor_rules)
	var power_row := HBoxContainer.new()
	column.add_child(power_row)
	var power_label := _localized_label("reactor-power-label", "reactor_current", 12, MUTED)
	power_label.custom_minimum_size.x = 180
	power_row.add_child(power_label)
	power_value_label = _label("reactor-power-value", "30 A", 16, CYAN)
	power_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_row.add_child(power_value_label)
	power_slider = HSlider.new()
	power_slider.name = "ReactorPower"
	_public(power_slider, "reactor-current", ["set_value"])
	power_slider.min_value = 0
	power_slider.max_value = 100
	power_slider.step = 1
	power_slider.custom_minimum_size.y = 22
	power_slider.value_changed.connect(state.set_power)
	column.add_child(power_slider)
	shield_check = CheckBox.new()
	shield_check.name = "ShieldEnabled"
	_public(shield_check, "shield-enabled", ["set_checked", "click"])
	_localized(shield_check, "field_shield")
	shield_check.toggled.connect(state.set_shield)
	column.add_child(shield_check)
	next_target_label = _label("operator-next-target", "", 10, CYAN)
	next_direction_label = _label("operator-next-direction", "", 10, TEXT)
	next_distance_label = _label("operator-next-distance", "", 10, TEXT)
	laser_staging_ready_label = _label("laser-staging-ready", "", 10, AMBER)
	for spatial_label in [next_target_label, next_direction_label, next_distance_label, laser_staging_ready_label]:
		column.add_child(spatial_label)
	_add_action_block(column, "door-a-requirement", "door_requirement", "door")
	_add_action_block(column, "exit-requirement", "exit_requirement", "exit")
	_add_action_block(column, "laser-suppression-requirement", "laser_requirement", "laser")
	var timer_row := HBoxContainer.new()
	column.add_child(timer_row)
	var timer_label := _localized_label("laser-suppression-remaining-label", "laser_remaining", 10, MUTED)
	timer_label.custom_minimum_size.x = 210
	timer_row.add_child(timer_label)
	laser_remaining = ProgressBar.new()
	laser_remaining.name = "LaserSuppressionRemaining"
	_public(laser_remaining, "laser-suppression-remaining", [])
	laser_remaining.min_value = 0.0
	laser_remaining.max_value = 6.0
	laser_remaining.step = 0.1
	laser_remaining.show_percentage = false
	laser_remaining.custom_minimum_size = Vector2(140, 14)
	timer_row.add_child(laser_remaining)
	laser_timing_state_label = _label("laser-suppression-state", "", 9, TEXT)
	laser_started_at_label = _label("laser-suppression-started-at", "", 9, TEXT)
	laser_ends_at_label = _label("laser-suppression-ends-at", "", 9, TEXT)
	laser_activation_id_label = _label("laser-suppression-activation-id", "", 9, TEXT)
	for timing_label in [laser_timing_state_label, laser_started_at_label, laser_ends_at_label, laser_activation_id_label]:
		column.add_child(timing_label)
	var laser_rules := _localized_label("laser-hazard-rules", "laser_hazard_rules", 9, AMBER)
	laser_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	laser_rules.custom_minimum_size.y = 25
	column.add_child(laser_rules)
	column.add_child(_separator())
	status_container = VBoxContainer.new()
	_public(status_container, "mission-status", [])
	column.add_child(status_container)
	location_label = _label("operator-location", "", 11, TEXT)
	shield_status_label = _label("operator-shielded", "", 11, TEXT)
	door_status_label = _label("door-status", "", 11, TEXT)
	laser_status_label = _label("laser-status", "", 11, RED)
	for item in [location_label, shield_status_label, door_status_label, laser_status_label]:
		status_container.add_child(item)
	_agent_only(panel)


func _add_action_block(column: VBoxContainer, requirement_id: String, requirement_key: String, kind: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var button := Button.new()
	button.custom_minimum_size = Vector2(155, 27)
	button.add_theme_font_size_override("font_size", 11)
	row.add_child(button)
	if kind == "door":
		door_button = button
		button.name = "DoorAControl"
		_public(button, "door-a-control", ["click"])
		button.pressed.connect(state.try_open_door_a)
	elif kind == "exit":
		exit_button = button
		button.name = "ExitControl"
		_public(button, "exit-control", ["click"])
		button.pressed.connect(state.try_unlock_exit)
	else:
		suppress_laser_button = button
		button.name = "SuppressLaser"
		_public(button, "suppress-laser", ["click"])
		button.pressed.connect(state.suppress_laser)
	var requirement := _localized_label(requirement_id, requirement_key, 10, MUTED)
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.custom_minimum_size.y = 27
	row.add_child(requirement)


func _build_human_current_readout() -> void:
	var panel := PanelContainer.new()
	panel.name = "FieldCurrentReadout"
	_private(panel, "field-current-readout")
	panel.position = Vector2(854, 92)
	panel.size = Vector2(408, 480)
	mission_screen.add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var title := _localized_label("field-current-title", "current_flow", 16, MUTED)
	title.set_meta("gua_agent_exposure", "private")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	current_readout_label = _label("field-current-value", "30 A", 64, CYAN)
	current_readout_label.set_meta("gua_agent_exposure", "private")
	current_readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_readout_label.custom_minimum_size = Vector2(300, 90)
	column.add_child(current_readout_label)


func _build_terminal() -> void:
	var panel := PanelContainer.new()
	panel.name = "CommunicationTerminal"
	_public(panel, "communication-terminal", [])
	panel.position = Vector2(18, 586)
	panel.size = Vector2(1244, 118)
	mission_screen.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var root_row := HBoxContainer.new()
	root_row.add_theme_constant_override("separation", 18)
	margin.add_child(root_row)
	var history_column := VBoxContainer.new()
	history_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_row.add_child(history_column)
	history_column.add_child(_localized_label("communication-history-title", "comms", 12, CYAN))
	history_label = _label("communication-history", "", 11, Color("9db8c3"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.clip_text = true
	history_label.custom_minimum_size.y = 70
	history_column.add_child(history_label)
	var human_column := VBoxContainer.new()
	human_column.custom_minimum_size.x = 430
	human_column.set_meta("gua_agent_exposure", "private")
	root_row.add_child(human_column)
	var composer_title := _localized_label("human-message-title", "message", 12, MUTED)
	composer_title.set_meta("gua_agent_exposure", "private")
	human_column.add_child(composer_title)
	var human_send_row := HBoxContainer.new()
	human_send_row.set_meta("gua_agent_exposure", "private")
	human_column.add_child(human_send_row)
	human_message_draft = LineEdit.new()
	human_message_draft.name = "HumanMessageDraft"
	_private(human_message_draft, "human-message-draft")
	_localized_placeholder(human_message_draft, "human_message_placeholder")
	human_message_draft.max_length = 180
	human_message_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_message_draft.text_submitted.connect(func(_value: String): _send_human_message())
	human_send_row.add_child(human_message_draft)
	var human_send := Button.new()
	human_send.name = "SendHumanMessage"
	_private(human_send, "send-human-message")
	_localized(human_send, "send")
	human_send.custom_minimum_size.x = 70
	human_send.pressed.connect(_send_human_message)
	human_send_row.add_child(human_send)
	var agent_send_row := HBoxContainer.new()
	agent_send_row.name = "AgentComposer"
	agent_send_row.position = Vector2(790, 32)
	agent_send_row.size = Vector2(430, 42)
	panel.add_child(agent_send_row)
	message_draft = LineEdit.new()
	message_draft.name = "AgentMessageDraft"
	_public(message_draft, "agent-message-draft", ["set_value"])
	_localized_placeholder(message_draft, "agent_message_placeholder")
	message_draft.max_length = 180
	message_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agent_send_row.add_child(message_draft)
	var agent_send := Button.new()
	agent_send.name = "SendAgentMessage"
	_public(agent_send, "send-agent-message", ["click"])
	_localized(agent_send, "send")
	agent_send.custom_minimum_size.x = 70
	agent_send.pressed.connect(_send_agent_message)
	agent_send_row.add_child(agent_send)
	_agent_only(agent_send_row)


func _build_result_overlay() -> void:
	overlay = ColorRect.new()
	overlay.name = "MissionResultOverlay"
	_public(overlay, "mission-result-overlay", [])
	overlay.color = Color("02070be6")
	overlay.position = Vector2(300, 178)
	overlay.size = Vector2(680, 310)
	overlay.visible = false
	mission_screen.add_child(overlay)
	overlay_title = _label("mission-result-title", "", 34, GREEN)
	overlay_title.position = Vector2(40, 46)
	overlay_title.size = Vector2(600, 55)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_title)
	overlay_text = _label("mission-result-description", "", 17, TEXT)
	overlay_text.position = Vector2(70, 120)
	overlay_text.size = Vector2(540, 70)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(overlay_text)
	return_title_button = Button.new()
	return_title_button.name = "ReturnToTitle"
	_public(return_title_button, "return-to-title", ["click"])
	_localized(return_title_button, "return_title")
	return_title_button.position = Vector2(220, 220)
	return_title_button.size = Vector2(240, 48)
	return_title_button.pressed.connect(_show_title)
	overlay.add_child(return_title_button)


func _start_game() -> void:
	if game_started:
		return
	state.reset()
	world.reset_player()
	title_screen.visible = false
	mission_screen.visible = true
	overlay.visible = false
	game_started = true
	world.set_active(true)
	_sync_ui()
	if ui != null:
		ui.update("mission")


func _show_title() -> void:
	game_started = false
	if world != null:
		world.set_active(false)
		world.reset_player()
	state.reset()
	if title_screen != null:
		title_screen.visible = true
	if mission_screen != null:
		mission_screen.visible = false
	if overlay != null:
		overlay.visible = false
	_sync_ui()
	if ui != null:
		ui.update("title")


func _toggle_locale() -> void:
	locale = GameTextScript.EN if locale == GameTextScript.JA else GameTextScript.JA
	state.set_locale(locale)
	_sync_localized_tree(self)
	_sync_language_toggle()
	_sync_ui()
	world.refresh_semantics()
	world.queue_redraw()


func _sync_language_toggle() -> void:
	if language_toggle != null:
		language_toggle.text = "ENGLISH" if locale == GameTextScript.JA else "日本語"


func _sync_ui() -> void:
	if objective_label == null:
		return
	objective_label.text = state.objective()
	hp_label.text = "HP %d%%" % state.hp
	hp_label.add_theme_color_override("font_color", GREEN if state.hp > 60 else AMBER if state.hp > 30 else RED)
	location_label.text = _text("status_location", [state.location_name()])
	shield_status_label.text = _text("status_shield", [_text("state_on") if state.shield_enabled else _text("state_off")])
	shield_status_label.add_theme_color_override("font_color", CYAN if state.shield_enabled else TEXT)
	door_status_label.text = _text("status_doors", [_text("state_open") if state.door_a_open else _text("state_locked"), _text("state_open") if state.exit_unlocked else _text("state_locked")])
	laser_status_label.text = _text("status_laser", [_text("state_active") if state.laser_is_active() else _text("state_suppressed")])
	laser_status_label.add_theme_color_override("font_color", RED if state.laser_is_active() else GREEN)
	power_value_label.text = "%d A" % int(state.reactor_power)
	current_readout_label.text = "%d A" % int(state.reactor_power)
	var rendered := state.rendered_message_history()
	history_label.text = "\n".join(rendered.slice(maxi(0, rendered.size() - 3)))
	if not power_slider.has_focus():
		power_slider.set_value_no_signal(state.reactor_power)
	shield_check.set_pressed_no_signal(state.shield_enabled)
	door_button.disabled = not state.can_open_door_a()
	door_button.text = _text("door_open") if state.door_a_open else _text("open_door")
	exit_button.disabled = not state.can_unlock_exit()
	exit_button.text = _text("exit_released") if state.exit_unlocked else _text("release_exit")
	suppress_laser_button.disabled = not state.can_suppress_laser()
	suppress_laser_button.text = _text("suppress_laser")
	_sync_live_ui()
	_sync_conditional_statuses()
	if overlay.visible:
		_sync_result_text()


func _sync_conditional_statuses() -> void:
	_status("partner-at-door-a", "conditional_at_door", state.at_door_a, AMBER)
	_status("partner-past-door-a", "conditional_past_door", state.past_door_a, GREEN)
	_status("partner-in-laser-corridor", "conditional_in_laser", state.in_laser_corridor, RED)
	_status("partner-at-laser-staging", "conditional_at_laser_staging", state.at_laser_staging, CYAN)
	_status("partner-through-laser", "conditional_through_laser", state.past_laser, GREEN)
	_status("partner-at-exit", "conditional_at_exit", state.at_exit and not state.mission_complete, GREEN)
	_status("door-a-open", "conditional_door_open", state.door_a_open, GREEN)
	_status("shield-active", "conditional_shield", state.shield_enabled, CYAN)
	_status("mission-complete", "conditional_complete", state.mission_complete, GREEN)


func _sync_live_ui() -> void:
	laser_remaining.value = snappedf(state.laser_remaining_seconds(), 0.1)
	next_target_label.text = _text("next_target", [_text(state.next_target_key())])
	next_direction_label.text = _text("next_direction", [_text(state.next_direction_key())])
	next_distance_label.text = _text("next_distance", [state.next_target_distance_meters()])
	laser_staging_ready_label.text = _text("laser_staging_ready", [_text("readiness_ready") if state.at_laser_staging else _text("readiness_not_ready")])
	laser_staging_ready_label.add_theme_color_override("font_color", GREEN if state.at_laser_staging else AMBER)
	laser_timing_state_label.text = _text("laser_timing_state", [_text("state_active") if state.laser_is_active() else _text("state_suppressed")])
	laser_started_at_label.text = _text("laser_started_at", [state.laser_started_at_text()])
	laser_ends_at_label.text = _text("laser_ends_at", [state.laser_ends_at_text()])
	laser_activation_id_label.text = _text("laser_activation_id", [state.laser_suppression_activation_id])


func _status(id: String, key: String, visible: bool, color: Color) -> void:
	var node := status_container.get_node_or_null(id)
	if visible and node == null:
		node = _localized_label(id, key, 10, color)
		node.name = id
		status_container.add_child(node)
	elif visible:
		node.text = _text(key)
	elif node != null:
		node.queue_free()


func _send_agent_message() -> void:
	if state.send_agent_message(message_draft.text):
		message_draft.clear()


func _send_human_message() -> void:
	if state.send_human_message(human_message_draft.text):
		human_message_draft.clear()


func _show_result(success: bool) -> void:
	world.set_active(false)
	overlay.visible = true
	_sync_result_text()
	overlay_title.add_theme_color_override("font_color", GREEN if success else RED)


func _sync_result_text() -> void:
	var success := state.mission_complete
	overlay_title.text = _text("mission_complete_title") if success else _text("mission_failed_title")
	overlay_text.text = _text("mission_complete_description", [state.format_time()]) if success else _text("mission_failed_description")


func _localized_label(id: String, key: String, font_size: int, color: Color) -> Label:
	var label := _label(id, _text(key), font_size, color)
	_localized(label, key)
	return label


func _label(id: String, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = id.to_pascal_case()
	_public(label, id, [])
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _localized(control: Control, key: String) -> Control:
	control.set_meta("localization_key", key)
	if control is Label or control is Button or control is CheckBox:
		control.text = _text(key)
	return control


func _localized_placeholder(control: LineEdit, key: String) -> LineEdit:
	control.set_meta("localization_placeholder_key", key)
	control.placeholder_text = _text(key)
	return control


func _sync_localized_tree(node: Node) -> void:
	if node is Control and node.has_meta("localization_key"):
		var control := node as Control
		if control is Label or control is Button or control is CheckBox:
			control.text = _text(str(control.get_meta("localization_key")))
	if node is LineEdit and node.has_meta("localization_placeholder_key"):
		node.placeholder_text = _text(str(node.get_meta("localization_placeholder_key")))
	for child in node.get_children():
		_sync_localized_tree(child)


func _public(control: Control, id: String, actions: Array) -> Control:
	control.set_meta("gua_id", id)
	control.set_meta("gua_agent_exposure", "auto")
	control.set_meta("gua_agent_allowed_actions", actions)
	return control


func _private(control: Control, id: String) -> Control:
	control.set_meta("gua_id", id)
	control.set_meta("gua_agent_exposure", "private")
	control.set_meta("gua_agent_allowed_actions", [])
	return control


func _agent_only(control: Control) -> void:
	control.modulate.a = 0.0
	_disable_human_input(control)


func _disable_human_input(node: Node) -> void:
	if node is Control:
		var item := node as Control
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_human_input(child)


func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color("244350"))
	return separator


func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


func _text(key: String, values: Array = []) -> String:
	return GameTextScript.text(locale, key, values)
