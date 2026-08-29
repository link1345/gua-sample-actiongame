# Gua Signal Relay

A browser action game where a human field operator and an AI control-room partner must observe the same mission, communicate, and act together.

Built with [Godot](https://godotengine.org/) and [Gua](https://github.com/link1345/gua), this project demonstrates semantic interaction with a Canvas/WebGL game through WebMCP. The human moves through the level directly, while the AI reads the live Semantic UI Tree, operates the control console, waits for mission conditions, and sends messages back into the game.

> Status: playable MVP implemented. The Godot Web Release, Gua Semantic UI, and in-page WebMCP bundle have been locally verified with Gua `v1.0.2`. The GitHub Pages workflow deploys updates from `main`.

English | [日本語](README-ja.md)

## Core experience

The game takes place in a damaged research station.

- **Human — Field Operator:** moves through hazards using keyboard controls, watches the current meter, and talks to the AI through chat.
- **AI — Control Operator:** uses a dedicated console hidden from the human to read warnings and mission status, control current, shields, doors, and the laser, and communicate through in-game chat.
- **Shared game state:** both participants observe and change the same running browser game.

A typical interaction:

1. The title screen asks the AI to start the game through WebMCP; humans can see but cannot press the button.
2. The human reaches Door A.
3. The AI reads a warning that current above 80A damages an unshielded partner.
4. The AI enables the shield, raises current, and opens the door.
5. The human advances while the AI reads the next semantic mission state.

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
- An AI-only Control Console and human-only current meter
- Bidirectional human/AI chat
- Semantic status nodes for mission conditions
- A Web build deployable at a public URL
- Independent state when the game is opened in two browser tabs
- Japanese/English UI switching that remains human-only and persists between missions
- A Player-projected World Object Tree with positions, spatial guidance, and hazard state

## Technology

- Godot 4.7
- GDScript
- Godot Web Export
- Gua Semantic UI
- Browser-native WebMCP
- `gl_compatibility` renderer

Pinned dependencies:

- Gua Godot addon `v1.0.2`
- `Gua.Testing` `v1.0.2`
- `Gua.Testing.Godot` `v1.0.2`
- `gua-webmcp` `v1.0.2`
- `gua-world-tools` `v1.0.2`

> The Godot addon is installed from the official `gua-godot-addon-v1.0.2.zip` release asset with SHA-256 verification. Windows Debug and Web Debug/Release binaries come from the same archive.

No external MCP server or WebSocket connection is required for the browser-native game path.

The Web build bundles M PLUS 1p under the SIL Open Font License so Japanese text renders consistently inside the Godot canvas. Its license is included at `assets/fonts/OFL-MPLUS1p.txt`.

## Play

1. The AI reads the title Semantic UI and calls `click_node("play-game")`. The visible start button ignores mouse and keyboard input, so the human cannot begin the mission.
2. The human moves the Field Operator to Door A with WASD or the arrow keys and tells the AI through chat.
3. The AI enables `FIELD SHIELD`, raises the current above 80A, and presses `OPEN DOOR A` in its private console.
4. The human checks the displayed current and passes through Door A.
5. The human stops at the outlined Laser Staging point. Only then does `Suppress Laser 6s` become enabled for the AI.
6. Before pressing it, the AI tells the human to run when the beams visibly turn off. The human crosses during the six-second window without waiting for a follow-up AI message.
7. At the Extraction Zone, the AI presses `RELEASE EXIT`, which becomes enabled only after the human arrives.

The human can switch the whole UI between Japanese and English at any time. This language control is private and does not appear in the AI's Player projection. System-generated messages are redrawn in the selected language; free-form human and AI chat is preserved verbatim.

Applying more than 80A without the shield or touching the laser causes damage. The human sees only the live current value and shared chat—not the AI Control Console or its controls.

## Local run and Web build

Godot 4.7, PowerShell 7, and Bun are required.

```powershell
.\scripts\install-gua.ps1

# First run only. The official Godot template archive is about 1.2 GB.
.\scripts\install-godot-web-templates.ps1

.\scripts\run-smoke.ps1
.\scripts\run-ui-tests.ps1
bun install --frozen-lockfile
bun run check:webmcp
.\scripts\build-web.ps1
```

The deployable output is `build/web/index.html`. Serve it over HTTP rather than opening it directly from disk.

Run the correlated Semantic UI mission test with:

```powershell
godot --headless --path . --script res://tests/mission_smoke.gd
```

The test covers the stopped title state, AI-only start, Player UI and World Object Trees, exclusion of human-only UI, meter-based guidance, prerequisite-driven enabled states, laser timing and damage, stable objectives, bilingual redraw, verbatim chat, evacuated location, mandatory AI restart, and request-correlated completion.

`mission_smoke.gd` is the fast in-process state-transition regression test. A separate `Gua.Testing.Godot` suite launches Godot as another process and operates the live Semantic UI over its WebSocket bridge:

```powershell
.\scripts\run-ui-tests.ps1 -GodotExecutable "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

The external UI test verifies the title instructions and AI-only start, World Object exposure before and after starting, prerequisite-driven disabled/enabled state for Door A, correlated `set_checked`, `set_value`, and `click` completion, and the published open state. Gua diagnostics are written under the test output's `artifacts/gua` directory on failure. The GitHub Pages build job runs this suite as well.

## AI Control Operator

A WebMCP-capable browser discovers `get_ui_tree`, `click_node`, `set_value`, `set_checked`, `select`, `wait_for_node`, and the other supported Gua tools directly on the page. A safe opening sequence is:

```text
get_ui_tree()
click_node("play-game")
set_value("agent-message-draft", "Wait at Door A. I will enable the shield first.")
click_node("send-agent-message")
wait_for_node("partner-at-door-a")
set_checked("shield-enabled", true)
set_value("reactor-current", "85")
click_node("door-a-control")
wait_for_node("partner-at-laser-staging")
set_value("agent-message-draft", "Run as soon as the laser beams turn off. Do not wait for my next message.")
click_node("send-agent-message")
click_node("suppress-laser")
```

Stable requirement nodes are `door-a-requirement`, `exit-requirement`, and `laser-suppression-requirement`. The read-only `laser-suppression-remaining` progress node exposes the current 0–6 second value in 0.1-second steps. `play-game` appears only on the title screen, and every replay requires a new AI click.

The AI console also exposes `operator-next-target`, `operator-next-direction`, `operator-next-distance`, and `laser-staging-ready`. Suppression history remains available through `laser-suppression-started-at`, `laser-suppression-ends-at`, and `laser-suppression-activation-id`, even after the laser returns to active.

`get_world_object_tree()` publishes seven read-only objects during the mission: `sector-a`, `field-operator`, `door-a`, `laser-staging-zone`, `laser-array`, `extraction-zone`, and `exit-airlock`. Positions use meters, and primitive state includes the operator zone, next target, distance, shield/HP, door state, laser timing, and extraction readiness. For example:

```text
get_world_object_tree()
find_world_objects({"id": "field-operator"})
find_world_objects({"id": "laser-array"})
```

Laser contact deals 28 HP at most once per second. Suppression expiry itself causes no damage unless the human is touching a beam, and there is no re-suppression cooldown. Crossing above 80A from 80A or below while unshielded deals 34 HP. WebMCP round-trip duration depends on the browser agent and is not guaranteed by the game, which is why the visible laser state—not a later chat response—is the start signal.

The browser path always uses Gua's Player projection. The AI-only Control Console is exposed only through that projection, while the human current meter and chat composer are marked `private` and excluded from the AI. Tool registrations and game state are isolated per browser tab.

## Related work

- [Gua WebMCP support — issue #71](https://github.com/link1345/gua/issues/71)
- [Semantic UI Tree exposure policy — issue #72](https://github.com/link1345/gua/issues/72)
- [OpenAI WebMCP Challenge](https://openai.com/webmcp-challenge/)

## License

MIT
