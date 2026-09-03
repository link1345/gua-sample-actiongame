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
	_check(game.ui != null, "Gua v1.0.10 adapter attaches")
	if game.ui == null:
		_finish()
		return

	# The mission is inert and only the title is projected until the AI starts it.
	game.ui.update("title")
	var title_tree: String = game.ui.get_player_ui_tree_json()
	var title_world: String = game.ui.get_player_world_object_tree_json()
	_check(not game.game_started, "mission does not auto-start")
	_check(title_tree.contains("play-game"), "title publishes the AI start action")
	_check(title_tree.contains("title-game-description"), "title explains the WebMCP game")
	_check(title_tree.contains("title-human-role") and title_tree.contains("title-ai-role"), "title publishes both player roles")
	_check(title_tree.contains("title-start-restriction"), "title publishes the human restriction")
	_check(title_tree.contains("AI Lovey-Dovey Kyun-Kyun! — Our First Mission Together"), "title defaults to the English game name")
	_check(not title_tree.contains("reactor-current"), "mission controls are hidden on title")
	_check(not title_tree.contains("language-toggle"), "human language toggle is private")
	_check(not title_world.contains("sector-a"), "title publishes no Player world objects")
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
	for id in ["door-a-requirement", "exit-requirement", "laser-suppression-requirement", "laser-suppression-remaining", "operator-next-target", "operator-next-direction", "operator-next-distance", "laser-staging-ready", "laser-suppression-state", "laser-suppression-started-at", "laser-suppression-ends-at", "laser-suppression-activation-id", "laser-hazard-rules", "reactor-hazard-rules"]:
		_check(mission_tree.contains(id), "mission publishes %s" % id)
	_check(not mission_tree.contains("play-game"), "title action is hidden during mission")
	_check(not mission_tree.contains("field-current-readout"), "AI tree hides human-only current readout")
	_check(not mission_tree.contains("human-message-draft") and not mission_tree.contains("send-human-message"), "mission has no human message composer")
	_check(not mission_tree.contains("agent-message-draft") and not mission_tree.contains("send-agent-message"), "mission has no in-game AI message composer")
	var mission_world: String = game.ui.get_player_world_object_tree_json()
	for id in ["sector-a", "field-operator", "door-a", "laser-staging-zone", "laser-array", "extraction-zone", "exit-airlock"]:
		_check(mission_world.contains(id), "Player world tree publishes %s" % id)
	_check(mission_world.contains("24.3") and mission_world.contains("distance_meters"), "world tree publishes meter-based next-target distance")
	_check(mission_world.contains("contact_damage_hp") and mission_world.contains("cooldown_seconds"), "world tree publishes laser hazard rules")
	var operator_query: String = game.ui.query_player_world_objects_json({"id": "field-operator"})
	_check(operator_query.contains("field-operator") and operator_query.contains("distance_meters"), "Player world query selects the field operator")

	# Button enabled states follow the published prerequisites.
	_check(game.door_button.disabled, "Door A begins disabled")
	_check(game.exit_button.disabled, "Exit begins disabled")
	_check(game.suppress_laser_button.disabled, "Laser begins disabled")
	await _action(game, {"action": "set_value", "node_id": "reactor-current", "value": "85"})
	_check(game.state.hp == 66, "unshielded current crossing deals exactly 34 HP")
	game.state.reset()
	game.world.reset_player()
	await process_frame
	await _action(game, {"action": "set_checked", "node_id": "shield-enabled", "bool_value": true})
	_check(game.door_button.disabled, "Door A still needs current above 80A")
	await _action(game, {"action": "set_value", "node_id": "reactor-current", "value": "85"})
	_check(not game.door_button.disabled, "Door A enables when shield and current are ready")
	await _action(game, {"action": "click", "node_id": "door-a-control"})
	_check(game.state.door_a_open, "Door A opens after prerequisites")
	_check(game.suppress_laser_button.disabled, "laser suppression stays disabled away from staging")
	game.world.player_position = Vector2(470, 320)
	game.world.call("_update_zones")
	game.world.refresh_semantics()
	await process_frame
	_check(game.state.at_laser_staging, "world reports the laser staging point")
	_check(not game.suppress_laser_button.disabled, "laser suppression enables at staging")
	_check(game.state.objective().contains("AI"), "staging objective asks AI to suppress the laser")
	_check(is_equal_approx(game.state.next_target_distance_meters(), 25.0), "next target advances to Extraction Zone with meter distance")
	await _action(game, {"action": "click", "node_id": "suppress-laser"})
	var initial_remaining: float = game.state.laser_remaining_seconds()
	_check(initial_remaining > 5.8 and initial_remaining <= 6.0, "laser suppression starts near six seconds")
	_check(game.state.laser_suppression_activation_id == 1, "laser activation id increments")
	_check(game.state.laser_suppression_started_at >= 0.0 and game.state.laser_suppressed_until > game.state.laser_suppression_started_at, "laser start and end times are retained")
	game.state.tick(1.2)
	game.call("_sync_ui")
	_check(absf(game.state.laser_remaining_seconds() - 4.8) < 0.11, "laser remaining time counts down")
	_check(absf(game.laser_remaining.value - 4.8) < 0.11, "laser remaining ProgressBar reports tenths")
	game.state.tick(5.0)
	game.call("_sync_ui")
	_check(game.state.laser_is_active(), "laser returns active at zero")
	_check(not game.suppress_laser_button.disabled, "laser can be suppressed again immediately with no cooldown")
	var retained_start: float = game.state.laser_suppression_started_at
	var retained_end: float = game.state.laser_suppressed_until

	# Laser damage applies only on beam contact, at most once per second.
	game.world.player_position = Vector2(520, 320)
	game.world.call("_update_zones")
	game.world.hit_cooldown = 0.0
	game.world.call("_update_hazard")
	_check(game.state.hp == 100, "suppression expiry does not damage away from a beam")
	game.world.player_position = Vector2(560, 320)
	game.world.call("_update_zones")
	game.world.call("_update_hazard")
	_check(game.state.hp == 72, "laser contact deals exactly 28 HP")
	game.world.call("_update_hazard")
	_check(game.state.hp == 72, "laser contact is limited to once per second")
	_check(is_equal_approx(game.state.laser_suppression_started_at, retained_start) and is_equal_approx(game.state.laser_suppressed_until, retained_end), "expired suppression timestamps remain available")

	# Objectives never regress after Door A, and exit unlock depends on position.
	game.world.player_position = Vector2(650, 320)
	game.world.call("_update_zones")
	await process_frame
	_check(game.state.past_laser, "world reports laser passage")
	_check(game.state.objective().contains("Extraction"), "objective advances to Extraction Zone after the laser")
	game.ui.update("mission")
	_check(game.ui.get_player_ui_tree_json().contains("partner-through-laser"), "partner-through-laser status is published")
	_check(game.exit_button.disabled, "Exit stays disabled before Extraction Zone")
	game.world.player_position = Vector2(720, 320)
	game.world.call("_update_zones")
	await process_frame
	_check(game.state.at_exit, "world reports Extraction Zone arrival")
	_check(not game.exit_button.disabled, "Exit enables at Extraction Zone")
	await _action(game, {"action": "click", "node_id": "exit-control"})
	_check(game.state.exit_unlocked, "Exit releases at Extraction Zone")

	# The system log localizes without exposing an in-game conversation composer.
	game.call("_toggle_locale")
	_check(game.locale == "ja", "human language toggle switches to Japanese")
	_check(game.state.objective().contains("エアロック"), "objective redraws in Japanese")
	var japanese_history := "\n".join(game.state.rendered_message_history())
	_check(japanese_history.contains("Door Aを解錠"), "system history redraws in Japanese")
	game.ui.update("mission")
	var japanese_tree: String = game.ui.get_player_ui_tree_json()
	_check(japanese_tree.contains("AIらぶらぶきゅんきゅん！初めての共同作業！"), "language switch publishes the Japanese game name")
	_check(not japanese_tree.contains("human-message-draft") and not japanese_tree.contains("agent-message-draft"), "message composers remain absent after switching")
	_check(japanese_tree.contains("door-a-requirement") and japanese_tree.contains("laser-suppression-remaining"), "semantic IDs survive language changes")
	_check(not japanese_tree.contains("language-toggle"), "language toggle remains private after switching")
	game.world.refresh_semantics()
	game.ui.update("mission")
	var japanese_world: String = game.ui.get_player_world_object_tree_json()
	_check(japanese_world.contains("レーザー待機地点") and japanese_world.contains("laser-staging-zone"), "world labels localize while world IDs remain stable")
	_check(japanese_world.contains("activation_id") and japanese_world.contains("started_at_seconds"), "world timing state survives language changes")

	game.state.complete()
	await process_frame
	game.ui.update("mission-complete")
	var complete_tree: String = game.ui.get_player_ui_tree_json()
	_check(game.state.location_name().contains("Airlock"), "completed location remains evacuated Airlock")
	_check(complete_tree.contains("return-to-title"), "result publishes return-to-title")
	await _action(game, {"action": "click", "node_id": "return-to-title"})
	_check(not game.game_started, "returning to title stops the mission")
	_check(game.locale == "ja", "language persists when returning to title")
	game.ui.update("title")
	var replay_tree: String = game.ui.get_player_ui_tree_json()
	_check(replay_tree.contains("play-game") and not replay_tree.contains("reactor-current"), "replay requires another AI start")
	_check(not game.ui.get_player_world_object_tree_json().contains("sector-a"), "returning to title hides Player world objects again")

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
