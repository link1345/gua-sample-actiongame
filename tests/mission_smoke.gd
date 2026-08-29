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
	game.ui.update("mission")
	var initial_tree: String = game.ui.get_player_ui_tree_json()
	_check(initial_tree.contains("power-warning-description"), "Player tree exposes safety warning")
	_check(initial_tree.contains("reactor-power"), "Player tree exposes reactor control")
	_check(initial_tree.contains("agent-message-draft"), "Player tree exposes communication draft")
	_check(not initial_tree.contains("mission-result-title"), "Player tree hides inactive result overlay")

	# Unsafe path: power above 80 without the shield must have a visible consequence.
	await _action(game, {"action": "set_value", "node_id": "reactor-power", "value": "85"})
	_check(game.state.hp == 66, "unsafe reactor surge damages the operator")

	# Safe path: the same controls, in the correct order, preserve HP and open the route.
	game.state.reset()
	game.world.reset_player()
	await process_frame
	await _action(game, {"action": "set_checked", "node_id": "shield-enabled", "bool_value": true})
	_check(game.state.shield_enabled, "set_checked enables the shield")
	await _action(game, {"action": "set_value", "node_id": "reactor-power", "value": "85"})
	_check(game.state.hp == 100, "shield prevents reactor surge damage")
	await _action(game, {"action": "click", "node_id": "door-a-control"})
	_check(game.state.door_a_open, "click opens Door A after prerequisites")
	await _action(game, {"action": "select", "node_id": "power-route", "value": "Maintenance / Suppress laser 6s"})
	_check(not game.state.laser_is_active(), "select suppresses the laser")

	game.world.player_position = Vector2(720, 320)
	await process_frame
	game.ui.update("mission")
	var exit_tree: String = game.ui.get_player_ui_tree_json()
	_check(exit_tree.contains("partner-at-exit"), "conditional partner-at-exit status appears")
	await _action(game, {"action": "click", "node_id": "exit-control"})
	_check(game.state.exit_unlocked, "click releases exit at extraction zone")

	await _action(game, {"action": "set_value", "node_id": "agent-message-draft", "value": "Exit is open. Move now!"})
	await _action(game, {"action": "click", "node_id": "send-agent-message"})
	_check(game.state.latest_agent_message == "Exit is open. Move now!", "AI message uses the in-game send flow")
	await _action(game, {"action": "click", "node_id": "human-ready"})
	_check(game.state.latest_human_reply == "Ready", "human reply is visible to Control")

	game.state.complete()
	await process_frame
	game.ui.update("mission-complete")
	var complete_tree: String = game.ui.get_player_ui_tree_json()
	_check(complete_tree.contains("mission-complete"), "mission-complete status is published")
	_check(complete_tree.contains("restart-mission"), "restart action is published after completion")

	game.queue_free()
	await process_frame
	_finish()


func _action(game: Node, request: Dictionary) -> void:
	game.ui.update("mission")
	request["observation_profile"] = 1
	var receipt: Dictionary = game.ui.enqueue_player_action(request)
	_check(int(receipt.get("error_code", -1)) == 0, "%s request is accepted" % request.get("action", "action"))
	var request_id := int(receipt.get("request_id", 0))
	for _attempt in range(4):
		game.ui.update("mission")
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
