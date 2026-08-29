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
var status_container: VBoxContainer
var power_slider: HSlider
var shield_check: CheckBox
var route_select: OptionButton
var door_button: Button
var exit_button: Button
var message_draft: LineEdit
var received_message: Label
var human_reply: Label
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
	var warning := _label("power-warning-description", "Power above 80% damages an unshielded field operator.", 13, TEXT)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 37
	warning_box.add_child(warning)

	var power_row := HBoxContainer.new()
	column.add_child(power_row)
	var power_label := _label("reactor-power-label", "REACTOR POWER", 13, MUTED)
	power_label.custom_minimum_size.x = 180
	power_row.add_child(power_label)
	power_value_label = _label("reactor-power-value", "30%", 17, CYAN)
	power_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_row.add_child(power_value_label)
	power_slider = HSlider.new()
	power_slider.name = "ReactorPower"
	_public(power_slider, "reactor-power", ["set_value"])
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

	var route_label := _label("power-route-label", "POWER ROUTE", 13, MUTED)
	column.add_child(route_label)
	route_select = OptionButton.new()
	route_select.name = "PowerRoute"
	_public(route_select, "power-route", ["select"])
	route_select.add_item("Primary / Door systems")
	route_select.add_item("Maintenance / Suppress laser 6s")
	route_select.item_selected.connect(state.set_route)
	column.add_child(route_select)

	var door_row := HBoxContainer.new()
	door_row.add_theme_constant_override("separation", 8)
	column.add_child(door_row)
	door_button = Button.new()
	door_button.name = "DoorAControl"
	_public(door_button, "door-a-control", ["click"])
	door_button.text = "OPEN DOOR A"
	door_button.custom_minimum_size = Vector2(176, 40)
	door_button.pressed.connect(state.try_open_door_a)
	door_row.add_child(door_button)
	exit_button = Button.new()
	exit_button.name = "ExitControl"
	_public(exit_button, "exit-control", ["click"])
	exit_button.text = "RELEASE EXIT"
	exit_button.custom_minimum_size = Vector2(176, 40)
	exit_button.pressed.connect(state.try_unlock_exit)
	door_row.add_child(exit_button)

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
	root_row.add_theme_constant_override("separation", 16)
	margin.add_child(root_row)

	var agent_column := VBoxContainer.new()
	agent_column.custom_minimum_size.x = 435
	root_row.add_child(agent_column)
	var agent_title := _label("agent-message-title", "CONTROL > FIELD", 12, CYAN)
	agent_column.add_child(agent_title)
	var send_row := HBoxContainer.new()
	agent_column.add_child(send_row)
	message_draft = LineEdit.new()
	message_draft.name = "AgentMessageDraft"
	_public(message_draft, "agent-message-draft", ["set_value", "focus"])
	message_draft.placeholder_text = "Message the field operator..."
	message_draft.max_length = 180
	message_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_draft.text_submitted.connect(func(_text: String): _send_agent_message())
	send_row.add_child(message_draft)
	var send := Button.new()
	send.name = "SendAgentMessage"
	_public(send, "send-agent-message", ["click"])
	send.text = "SEND"
	send.custom_minimum_size.x = 70
	send.pressed.connect(_send_agent_message)
	send_row.add_child(send)
	received_message = _label("received-agent-message", "", 12, TEXT)
	received_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	received_message.custom_minimum_size.y = 34
	agent_column.add_child(received_message)

	var reply_column := VBoxContainer.new()
	reply_column.custom_minimum_size.x = 370
	root_row.add_child(reply_column)
	var reply_title := _label("human-reply-title", "FIELD > CONTROL", 12, AMBER)
	reply_column.add_child(reply_title)
	var reply_buttons := HBoxContainer.new()
	reply_buttons.add_theme_constant_override("separation", 5)
	reply_column.add_child(reply_buttons)
	for data in [["human-ready", "READY"], ["human-wait", "WAIT"], ["human-need-shield", "NEED SHIELD"], ["human-repeat", "REPEAT"]]:
		var button := Button.new()
		button.name = str(data[0]).to_pascal_case()
		_public(button, data[0], ["click"])
		button.text = data[1]
		button.custom_minimum_size.y = 34
		button.pressed.connect(state.send_human_reply.bind(data[1].capitalize()))
		reply_buttons.add_child(button)
	human_reply = _label("latest-human-reply", "No response yet", 12, TEXT)
	reply_column.add_child(human_reply)

	var history_column := VBoxContainer.new()
	history_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_row.add_child(history_column)
	var history_title := _label("communication-history-title", "SIGNAL LOG", 12, MUTED)
	history_column.add_child(history_title)
	history_label = _label("communication-history", "", 11, Color("9db8c3"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.clip_text = true
	history_label.custom_minimum_size.y = 70
	history_column.add_child(history_label)


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
	power_value_label.text = "%d%%" % int(state.reactor_power)
	received_message.text = state.latest_agent_message
	human_reply.text = "Latest: %s" % state.latest_human_reply
	history_label.text = "\n".join(state.message_history.slice(maxi(0, state.message_history.size() - 3)))
	if not power_slider.has_focus(): power_slider.set_value_no_signal(state.reactor_power)
	shield_check.set_pressed_no_signal(state.shield_enabled)
	route_select.select(state.power_route)
	door_button.disabled = state.door_a_open or state.mission_complete or state.mission_failed
	door_button.text = "DOOR A OPEN" if state.door_a_open else "OPEN DOOR A"
	exit_button.disabled = state.exit_unlocked or state.mission_complete or state.mission_failed
	exit_button.text = "EXIT RELEASED" if state.exit_unlocked else "RELEASE EXIT"
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
