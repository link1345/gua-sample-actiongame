extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.ui != null, "Gua v1.0.2 adapter attaches")
	if game.ui == null:
		_finish()
		return

	# The mission is inert and only the title is projected until the AI starts it.
	game.ui.update("title")
	var title_tree: String = game.ui.get_player_ui_tree_json()
	_check(not game.game_started, "mission does not auto-start")
	_check(title_tree.contains("play-game"), "title publishes the AI start action")
	_check(title_tree.contains("title-game-description"), "title explains the WebMCP game")
	_check(title_tree.contains("title-human-role") and title_tree.contains("title-ai-role"), "title publishes both player roles")
	_check(title_tree.contains("title-start-restriction"), "title publishes the human restriction")
	_check(not title_tree.contains("reactor-current"), "mission controls are hidden on title")
	_check(not title_tree.contains("language-toggle"), "human language toggle is private")
	_check(game.play_game_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "human pointer input cannot press play")
	_check(game.play_game_button.focus_mode == Control.FOCUS_NONE, "human keyboard focus cannot press play")
	var initial_position: Vector2 = game.world.player_position
	await create_timer(0.15).timeout
	_check(is_zero_approx(game.state.elapsed), "mission clock stays stopped on title")
	_check(game.world.player_position == initial_position, "player stays stopped on title")

	await _action(game, {"action": "click", "node_id": "play-game"})
	_check(game.game_started, "Gua click starts the mission")
	game.ui.update("mission")
	var mission_tree: String = game.ui.get_player_ui_tree_json()
	for id in ["reactor-current", "shield-enabled", "door-a-control", "exit-control", "suppress-laser"]:
		_check(mission_tree.contains(id), "mission publishes %s" % id)
	for id in ["door-a-requirement", "exit-requirement", "laser-suppression-requirement", "laser-suppression-remaining"]:
		_check(mission_tree.contains(id), "mission publishes %s" % id)
	_check(not mission_tree.contains("play-game"), "title action is hidden during mission")
	_check(not mission_tree.contains("field-current-readout"), "AI tree hides human-only current readout")
	_check(not mission_tree.contains("human-message-draft"), "AI tree hides human chat composer")

	# Button enabled states follow the published prerequisites.
	_check(game.door_button.disabled, "Door A begins disabled")
	_check(game.exit_button.disabled, "Exit begins disabled")
	_check(game.suppress_laser_button.disabled, "Laser begins disabled")
	await _action(game, {"action": "set_checked", "node_id": "shield-enabled", "bool_value": true})
	_check(game.door_button.disabled, "Door A still needs current above 80A")
	await _action(game, {"action": "set_value", "node_id": "reactor-current", "value": "85"})
	_check(not game.door_button.disabled, "Door A enables when shield and current are ready")
	await _action(game, {"action": "click", "node_id": "door-a-control"})
	_check(game.state.door_a_open, "Door A opens after prerequisites")
	_check(not game.suppress_laser_button.disabled, "laser suppression enables after Door A")
	await _action(game, {"action": "click", "node_id": "suppress-laser"})
	var initial_remaining: float = game.state.laser_remaining_seconds()
	_check(initial_remaining > 5.8 and initial_remaining <= 6.0, "laser suppression starts near six seconds")
	game.state.tick(1.2)
	game.call("_sync_ui")
	_check(absf(game.state.laser_remaining_seconds() - 4.8) < 0.11, "laser remaining time counts down")
	_check(absf(game.laser_remaining.value - 4.8) < 0.11, "laser remaining ProgressBar reports tenths")
	game.state.tick(5.0)
	game.call("_sync_ui")
	_check(game.state.laser_is_active(), "laser returns active at zero")

	# Objectives never regress after Door A, and exit unlock depends on position.
	game.state.at_door_a = false
	game.state.past_door_a = true
	var past_door_objective: String = game.state.objective()
	_check(past_door_objective.contains("レーザー"), "objective advances to the laser after Door A")
	_check(game.exit_button.disabled, "Exit stays disabled before Extraction Zone")
	game.world.player_position = Vector2(720, 320)
	game.world.call("_update_zones")
	await process_frame
	_check(game.state.at_exit, "world reports Extraction Zone arrival")
	_check(not game.exit_button.disabled, "Exit enables at Extraction Zone")
	await _action(game, {"action": "click", "node_id": "exit-control"})
	_check(game.state.exit_unlocked, "Exit releases at Extraction Zone")

	# Generated messages localize, while human and AI free text remains unchanged.
	await _action(game, {"action": "set_value", "node_id": "agent-message-draft", "value": "Move now!"})
	await _action(game, {"action": "click", "node_id": "send-agent-message"})
	game.human_message_draft.text = "了解。進みます。"
	game.call("_send_human_message")
	game.call("_toggle_locale")
	_check(game.locale == "en", "human language toggle switches to English")
	_check(game.state.objective().contains("airlock"), "objective redraws in English")
	var english_history := "\n".join(game.state.rendered_message_history())
	_check(english_history.contains("Door A unlocked"), "system history redraws in English")
	_check(english_history.contains("Move now!") and english_history.contains("了解。進みます。"), "free-form chat remains verbatim")
	game.ui.update("mission")
	var english_tree: String = game.ui.get_player_ui_tree_json()
	_check(english_tree.contains("door-a-requirement") and english_tree.contains("laser-suppression-remaining"), "semantic IDs survive language changes")
	_check(not english_tree.contains("language-toggle"), "language toggle remains private after switching")

	game.state.complete()
	await process_frame
	game.ui.update("mission-complete")
	var complete_tree: String = game.ui.get_player_ui_tree_json()
	_check(game.state.location_name().contains("Airlock"), "completed location remains evacuated Airlock")
	_check(complete_tree.contains("return-to-title"), "result publishes return-to-title")
	await _action(game, {"action": "click", "node_id": "return-to-title"})
	_check(not game.game_started, "returning to title stops the mission")
	_check(game.locale == "en", "language persists when returning to title")
	game.ui.update("title")
	var replay_tree: String = game.ui.get_player_ui_tree_json()
	_check(replay_tree.contains("play-game") and not replay_tree.contains("reactor-current"), "replay requires another AI start")

	game.queue_free()
	await process_frame
	_finish()


func _action(game: Node, request: Dictionary) -> void:
	game.ui.update(game.call("_screen_name"))
	request["observation_profile"] = 1
	var receipt: Dictionary = game.ui.enqueue_player_action(request)
	_check(int(receipt.get("error_code", -1)) == 0, "%s request is accepted" % request.get("action", "action"))
	var request_id := int(receipt.get("request_id", 0))
	for _attempt in range(5):
		game.ui.update(game.call("_screen_name"))
		await process_frame
		var result: Dictionary = game.ui.poll_action_result(request_id)
		if not result.is_empty():
			_check(bool(result.get("succeeded", false)), "%s request completes" % request.get("action", "action"))
			return
	_check(false, "%s request completion is correlated" % request.get("action", "action"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.push_back(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MISSION_SMOKE_PASSED")
		quit(0)
	else:
		print("MISSION_SMOKE_FAILED: ", ", ".join(failures))
		quit(1)
