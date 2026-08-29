extends Control

const GuaAutoAdapterScript := preload("res://addons/gua/gua_auto_adapter.gd")
const MissionStateScript := preload("res://scripts/mission_state.gd")
const WorldScript := preload("res://scripts/game_world.gd")

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
var ui
var world: SignalRelayWorld
var objective_label: Label
var hp_label: Label
var location_label: Label
var shield_status_label: Label
var door_status_label: Label
var laser_status_label: Label
var power_value_label: Label
var current_readout_label: Label
var status_container: VBoxContainer
var power_slider: HSlider
var shield_check: CheckBox
var door_button: Button
var exit_button: Button
var suppress_laser_button: Button
var message_draft: LineEdit
var human_message_draft: LineEdit
var history_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_text: Label
var restart_button: Button


func _ready() -> void:
	set_meta("gua_id", "mission-root")
	set_meta("gua_agent_exposure", "auto")
	_build_theme()
	_build_interface()
	state.changed.connect(_sync_ui)
	state.mission_finished.connect(_show_result)
	state.reset()
	_setup_gua()
	_sync_ui()


func _exit_tree() -> void:
	if ui != null and ui.has_method("dispose"):
		ui.dispose()


func _process(_delta: float) -> void:
	if ui != null:
		ui.update("mission-complete" if state.mission_complete else "mission-failed" if state.mission_failed else "mission")


func _setup_gua() -> void:
	if not ResourceLoader.exists("res://addons/gua/gua_auto_adapter.gd"):
		push_warning("Gua v1.0.2 addon is not installed. Run scripts/install-gua.ps1 before testing WebMCP.")
		return
	ui = GuaAutoAdapterScript.new()
	ui.attach(self)


func _build_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_stylebox("normal", "Button", _box(PANEL_2, Color("2c5364"), 6))
	theme.set_stylebox("hover", "Button", _box(Color("173b4b"), CYAN, 6))
	theme.set_stylebox("pressed", "Button", _box(CYAN, CYAN, 6))
	theme.set_stylebox("disabled", "Button", _box(Color("111c23"), Color("293a43"), 6))
	theme.set_stylebox("normal", "LineEdit", _box(Color("07131d"), Color("2b5363"), 5))
	theme.set_stylebox("focus", "LineEdit", _box(Color("07131d"), CYAN, 5))
	theme.set_stylebox("normal", "OptionButton", _box(Color("07131d"), Color("2b5363"), 5))
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("1c3b49"), 8))
	theme.set_stylebox("slider", "HSlider", _flat(Color("25414d")))
	theme.set_stylebox("grabber_area", "HSlider", _flat(CYAN))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color.WHITE))
	self.theme = theme


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var header := ColorRect.new()
	header.color = Color("091824")
	header.position = Vector2(18, 16)
	header.size = Vector2(1244, 62)
	add_child(header)

	var title := _label("mission-title", "GUA // SIGNAL RELAY", 24, CYAN)
	title.position = Vector2(38, 26)
	title.size = Vector2(340, 28)
	add_child(title)
	var subtitle := _label("mission-subtitle", "ESCAPE FROM SECTOR A", 12, MUTED)
	subtitle.position = Vector2(40, 53)
	subtitle.size = Vector2(300, 18)
	add_child(subtitle)

	objective_label = _label("current-objective", "", 18, TEXT)
	objective_label.position = Vector2(372, 27)
	objective_label.size = Vector2(580, 42)
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(objective_label)

	hp_label = _label("operator-hp", "HP 100%", 20, GREEN)
	hp_label.position = Vector2(1050, 26)
	hp_label.size = Vector2(180, 34)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hp_label)

	world = WorldScript.new()
	world.name = "FieldView"
	world.set_meta("gua_id", "field-world-view")
	world.position = Vector2(18, 92)
	world.size = Vector2(820, 480)
	add_child(world)
	world.setup(state)

	_build_console()
	_build_human_current_readout()
	_build_terminal()
	_build_result_overlay()


func _build_console() -> void:
	var panel := PanelContainer.new()
	panel.name = "ControlConsole"
	panel.set_meta("gua_id", "control-console")
	panel.position = Vector2(854, 92)
	panel.size = Vector2(408, 480)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var heading := _label("console-title", "AI CONTROL CONSOLE", 19, CYAN)
	column.add_child(heading)
	var live := _label("console-link-status", "[LINK] SECURE / PLAYER PROFILE", 11, GREEN)
	column.add_child(live)
	column.add_child(_separator())

	var warning_box := VBoxContainer.new()
	warning_box.name = "PowerWarning"
	warning_box.set_meta("gua_id", "power-warning")
	warning_box.set_meta("gua_agent_exposure", "auto")
	column.add_child(warning_box)
	var warning_title := _label("power-warning-title", "! REACTOR SAFETY WARNING", 14, AMBER)
	warning_box.add_child(warning_title)
	var warning := _label("power-warning-description", "Current above 80A damages an unshielded field operator.", 13, TEXT)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 37
	warning_box.add_child(warning)

	var power_row := HBoxContainer.new()
	column.add_child(power_row)
	var power_label := _label("reactor-power-label", "REACTOR CURRENT", 13, MUTED)
	power_label.custom_minimum_size.x = 180
	power_row.add_child(power_label)
	power_value_label = _label("reactor-power-value", "30 A", 17, CYAN)
	power_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_row.add_child(power_value_label)
	power_slider = HSlider.new()
	power_slider.name = "ReactorPower"
	_public(power_slider, "reactor-current", ["set_value"])
	power_slider.min_value = 0
	power_slider.max_value = 100
	power_slider.step = 1
	power_slider.value = 30
	power_slider.custom_minimum_size.y = 28
	power_slider.value_changed.connect(state.set_power)
	column.add_child(power_slider)

	shield_check = CheckBox.new()
	shield_check.name = "ShieldEnabled"
	_public(shield_check, "shield-enabled", ["set_checked", "click"])
	shield_check.text = "FIELD SHIELD"
	shield_check.toggled.connect(state.set_shield)
	column.add_child(shield_check)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	column.add_child(action_row)
	door_button = Button.new()
	door_button.name = "DoorAControl"
	_public(door_button, "door-a-control", ["click"])
	door_button.text = "OPEN DOOR A"
	door_button.custom_minimum_size = Vector2(116, 44)
	door_button.pressed.connect(state.try_open_door_a)
	action_row.add_child(door_button)
	exit_button = Button.new()
	exit_button.name = "ExitControl"
	_public(exit_button, "exit-control", ["click"])
	exit_button.text = "RELEASE EXIT"
	exit_button.custom_minimum_size = Vector2(116, 44)
	exit_button.pressed.connect(state.try_unlock_exit)
	action_row.add_child(exit_button)
	suppress_laser_button = Button.new()
	suppress_laser_button.name = "SuppressLaser"
	_public(suppress_laser_button, "suppress-laser", ["click"])
	suppress_laser_button.text = "Suppress Laser 6s"
	suppress_laser_button.custom_minimum_size = Vector2(126, 44)
	suppress_laser_button.pressed.connect(state.suppress_laser)
	action_row.add_child(suppress_laser_button)

	column.add_child(_separator())
	status_container = VBoxContainer.new()
	status_container.name = "MissionStatus"
	status_container.set_meta("gua_id", "mission-status")
	column.add_child(status_container)
	location_label = _label("operator-location", "Arrival bay", 13, TEXT)
	shield_status_label = _label("operator-shielded", "Shield: OFF", 13, TEXT)
	door_status_label = _label("door-status", "Door A: LOCKED / Exit: LOCKED", 13, TEXT)
	laser_status_label = _label("laser-status", "Laser: ACTIVE", 13, RED)
	for item in [location_label, shield_status_label, door_status_label, laser_status_label]:
		status_container.add_child(item)
	_agent_only(panel)


func _build_human_current_readout() -> void:
	var panel := PanelContainer.new()
	panel.name = "FieldCurrentReadout"
	panel.set_meta("gua_id", "field-current-readout")
	panel.set_meta("gua_agent_exposure", "private")
	panel.position = Vector2(854, 92)
	panel.size = Vector2(408, 480)
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var title := _label("field-current-title", "CURRENT FLOW", 16, MUTED)
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
	panel.set_meta("gua_id", "communication-terminal")
	panel.position = Vector2(18, 586)
	panel.size = Vector2(1244, 118)
	add_child(panel)
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
	var history_title := _label("communication-history-title", "COMMS", 12, CYAN)
	history_column.add_child(history_title)
	history_label = _label("communication-history", "", 11, Color("9db8c3"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.clip_text = true
	history_label.custom_minimum_size.y = 70
	history_column.add_child(history_label)

	var human_column := VBoxContainer.new()
	human_column.custom_minimum_size.x = 430
	human_column.set_meta("gua_agent_exposure", "private")
	root_row.add_child(human_column)
	var composer_title := _label("human-message-title", "MESSAGE", 12, MUTED)
	composer_title.set_meta("gua_agent_exposure", "private")
	human_column.add_child(composer_title)
	var human_send_row := HBoxContainer.new()
	human_send_row.set_meta("gua_agent_exposure", "private")
	human_column.add_child(human_send_row)
	human_message_draft = LineEdit.new()
	human_message_draft.name = "HumanMessageDraft"
	_private(human_message_draft, "human-message-draft")
	human_message_draft.placeholder_text = "Message AI Control..."
	human_message_draft.max_length = 180
	human_message_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_message_draft.text_submitted.connect(func(_text: String): _send_human_message())
	human_send_row.add_child(human_message_draft)
	var human_send := Button.new()
	human_send.name = "SendHumanMessage"
	_private(human_send, "send-human-message")
	human_send.text = "SEND"
	human_send.custom_minimum_size.x = 70
	human_send.pressed.connect(_send_human_message)
	human_send_row.add_child(human_send)

	# The AI composer remains visible to Gua but is transparent and cannot receive human input.
	var agent_send_row := HBoxContainer.new()
	agent_send_row.name = "AgentComposer"
	agent_send_row.position = Vector2(790, 32)
	agent_send_row.size = Vector2(430, 42)
	panel.add_child(agent_send_row)
	message_draft = LineEdit.new()
	message_draft.name = "AgentMessageDraft"
	_public(message_draft, "agent-message-draft", ["set_value"])
	message_draft.placeholder_text = "Message the field operator..."
	message_draft.max_length = 180
	message_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agent_send_row.add_child(message_draft)
	var agent_send := Button.new()
	agent_send.name = "SendAgentMessage"
	_public(agent_send, "send-agent-message", ["click"])
	agent_send.text = "SEND"
	agent_send.custom_minimum_size.x = 70
	agent_send.pressed.connect(_send_agent_message)
	agent_send_row.add_child(agent_send)
	_agent_only(agent_send_row)


func _build_result_overlay() -> void:
	overlay = ColorRect.new()
	overlay.name = "MissionResultOverlay"
	overlay.set_meta("gua_id", "mission-result-overlay")
	overlay.color = Color("02070be6")
	overlay.position = Vector2(300, 178)
	overlay.size = Vector2(680, 310)
	overlay.visible = false
	add_child(overlay)
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
	restart_button = Button.new()
	restart_button.name = "RestartMission"
	_public(restart_button, "restart-mission", ["click"])
	restart_button.text = "RESTART OPERATION"
	restart_button.position = Vector2(220, 220)
	restart_button.size = Vector2(240, 48)
	restart_button.pressed.connect(_restart)
	overlay.add_child(restart_button)


func _sync_ui() -> void:
	objective_label.text = state.objective()
	hp_label.text = "HP %d%%" % state.hp
	hp_label.add_theme_color_override("font_color", GREEN if state.hp > 60 else AMBER if state.hp > 30 else RED)
	location_label.text = "LOCATION  %s" % state.location_name().to_upper()
	shield_status_label.text = "SHIELD    %s" % ("ACTIVE" if state.shield_enabled else "OFF")
	shield_status_label.add_theme_color_override("font_color", CYAN if state.shield_enabled else TEXT)
	door_status_label.text = "DOORS     A: %s  /  EXIT: %s" % ["OPEN" if state.door_a_open else "LOCKED", "OPEN" if state.exit_unlocked else "LOCKED"]
	laser_status_label.text = "LASER     %s" % ("ACTIVE" if state.laser_is_active() else "SUPPRESSED")
	laser_status_label.add_theme_color_override("font_color", RED if state.laser_is_active() else GREEN)
	power_value_label.text = "%d A" % int(state.reactor_power)
	current_readout_label.text = "%d A" % int(state.reactor_power)
	history_label.text = "\n".join(state.message_history.slice(maxi(0, state.message_history.size() - 3)))
	if not power_slider.has_focus(): power_slider.set_value_no_signal(state.reactor_power)
	shield_check.set_pressed_no_signal(state.shield_enabled)
	door_button.disabled = state.door_a_open or state.mission_complete or state.mission_failed
	door_button.text = "DOOR A OPEN" if state.door_a_open else "OPEN DOOR A"
	exit_button.disabled = state.exit_unlocked or state.mission_complete or state.mission_failed
	exit_button.text = "EXIT RELEASED" if state.exit_unlocked else "RELEASE EXIT"
	suppress_laser_button.disabled = state.mission_complete or state.mission_failed
	_sync_conditional_statuses()


func _sync_conditional_statuses() -> void:
	_status("partner-at-door-a", "STATUS: Partner at Door A", state.at_door_a, AMBER)
	_status("partner-past-door-a", "STATUS: Partner past Door A", state.past_door_a, GREEN)
	_status("partner-in-laser-corridor", "STATUS: Partner in laser corridor", state.in_laser_corridor, RED)
	_status("partner-at-exit", "STATUS: Partner at extraction zone", state.at_exit, GREEN)
	_status("door-a-open", "STATUS: Door A open", state.door_a_open, GREEN)
	_status("shield-active", "STATUS: Shield active", state.shield_enabled, CYAN)
	_status("mission-complete", "STATUS: Mission complete", state.mission_complete, GREEN)


func _status(id: String, text: String, visible: bool, color: Color) -> void:
	var node := status_container.get_node_or_null(id)
	if visible and node == null:
		node = _label(id, text, 11, color)
		node.name = id
		status_container.add_child(node)
	elif not visible and node != null:
		node.queue_free()


func _send_agent_message() -> void:
	if state.send_agent_message(message_draft.text):
		message_draft.clear()


func _send_human_message() -> void:
	if state.send_human_message(human_message_draft.text):
		human_message_draft.clear()


func _show_result(success: bool) -> void:
	overlay.visible = true
	overlay_title.text = "MISSION COMPLETE" if success else "MISSION FAILED"
	overlay_title.add_theme_color_override("font_color", GREEN if success else RED)
	overlay_text.text = ("Sector A evacuated in %s. Human and AI control signals remained synchronized." % state.format_time()) if success else "Field operator signal lost. Review the safety warning and coordinate the shield before applying reactor power."


func _restart() -> void:
	overlay.visible = false
	world.reset_player()
	state.reset()


func _label(id: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = id.to_pascal_case()
	_public(label, id, [])
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
