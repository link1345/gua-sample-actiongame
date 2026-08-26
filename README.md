# Gua Signal Relay

A browser action game where a human field operator and an AI control-room partner must observe the same mission, communicate, and act together.

Built with [Godot](https://godotengine.org/) and [Gua](https://github.com/link1345/gua), this project demonstrates semantic interaction with a Canvas/WebGL game through WebMCP. The human moves through the level directly, while the AI reads the live Semantic UI Tree, operates the control console, waits for mission conditions, and sends messages back into the game.

> Status: pre-production. The WebMCP runtime work is tracked in [Gua issue #71](https://github.com/link1345/gua/issues/71).

English | [日本語](README-ja.md)

## Core experience

The game takes place in a damaged research station.

- **Human — Field Operator:** moves through hazards using keyboard controls.
- **AI — Control Operator:** reads warnings and mission status, routes power, enables shields, opens doors, and communicates through the in-game terminal.
- **Shared game state:** both participants observe and change the same running browser game.

A typical interaction:

1. The human reaches Door A.
2. The AI reads a warning that power above 80% damages an unshielded partner.
3. The AI sends an in-game message asking the human to wait.
4. The AI enables the shield, routes power, and opens the door.
5. The human advances while the AI waits for the next semantic mission state.

## Why WebMCP

Godot Web Export renders the game through Canvas/WebGL, where ordinary DOM-based automation cannot reliably understand game controls or state. Gua provides a Semantic UI Tree with stable node IDs, roles, labels, text, state, supported actions, and request-correlated completion.

The page exposes that semantic interaction through WebMCP, allowing a browser agent to use structured tools instead of guessing coordinates from pixels.

Planned tools include:

- `get_ui_tree`
- `click_node`
- `set_value`
- `set_checked`
- `select`
- `wait_for_node`
- `get_screenshot` when supported

## MVP

The first playable build is one short two-to-three-minute mission containing:

- Top-down player movement
- One power-routing puzzle
- One shield and damage warning
- Two remotely controlled doors
- One moving or cycling hazard
- An AI-to-human message terminal
- Human response controls
- Semantic status nodes for mission conditions
- A Web build deployable at a public URL
- Independent state when the game is opened in two browser tabs

## Technology

- Godot 4.7
- GDScript
- Godot Web Export
- Gua Semantic UI
- Browser-native WebMCP
- `gl_compatibility` renderer

No external MCP server or WebSocket connection is required for the browser-native game path.

## Related work

- [Gua WebMCP support — issue #71](https://github.com/link1345/gua/issues/71)
- [Semantic UI Tree exposure policy — issue #72](https://github.com/link1345/gua/issues/72)
- [OpenAI WebMCP Challenge](https://openai.com/webmcp-challenge/)

## License

MIT
