# Bananarc — Godot 4 vertical slice

A playable slice of the game specced in [`../docs/PRD.md`](../docs/PRD.md),
built on [Godot Engine 4.4](https://godotengine.org).

## Run it

1. Install [Godot 4.4+](https://godotengine.org/download) (standard build).
2. Open this folder as a project, or from a terminal:

   ```sh
   godot --path game
   ```

## What's implemented

| System | Status |
|---|---|
| Classic physics (`src/sim/integrator.gd`) | Exact GORILLA.BAS model: closed-form trajectory, gravity 9.8, quadratic wind drift, classic wind roll with gusts. Fixed-timestep, engine-independent, deterministic — Godot renders the banana, it never simulates it. |
| Procedural city (`src/sim/city_gen.gd`) | Fresh seeded skyline every round: rolled widths/heights/slope profile/materials, **guaranteed interceptor**, solver-backed **solvability check** for both players, **distinctness check** vs the previous round. |
| Destruction (`src/sim/city_data.gd`) | 1-unit occupancy grid; craters carve cells; the render rebuilds from the grid so visuals always equal collision truth. Craters persist for the round. |
| Weather & lighting (`src/weather.gd`) | All nine conditions with clock times. Real `DirectionalLight3D` sun/moon per condition, sky + fog environment, GPU rain/snow, ambient lightning in storms. Presentation-first — never touches the sim. |
| True 3D scene (`src/city_view.gd`) | Perspective camera, side-on frame, cell-built building volumes with emissive windows (lit fraction follows time of day), ground, two background depth lanes, landmark spire, trestle water tower. |
| Gorillas (`src/gorilla.gd`) | Placeholder primitive characters with the full animation contract: idle sway, aim pose tracking the ANGLE meter, windup-throw scaled by power, flinch, defeat, 3-loop chest-beat victory. Production swaps visuals for the Meshy pipeline asset (PRD §12). |
| Physics overlay (`src/overlay.gd`) | Launch vector + live v·cosθ / v·sinθ decomposition + angle arc + short windless ghost arc; white dotted flight trace. |
| HUD (`src/hud.gd`) | Concept layout: weather+time top-left, full-width bar PLAYER · POWER · WIND · ANGLE · PLAYER with typed entry, debrief card with wind drift, title & match-end overlays. |
| Modes (`src/main.gd`) | Hot-seat 2P and Solo vs AI (converging Silverback-style AI, `src/ai.gd`). First to 3 points; aim values persist per player between throws, classic style. |

## Controls

- Drag the **POWER** / **ANGLE** sliders, or type exact numbers and press
  Enter in the fields (classic ritual).
- **Throw:** Enter / Space, or click your gorilla.
- Self-hits score for the opponent, exactly like 1991.

## Tests

Headless simulation-core smoke test (RNG determinism, generation
guarantees, trajectory + wind drift, destruction, AI planning):

```sh
godot --headless --path game -s tests/smoke.gd
```

Full-loop autotest — AI vs AI, fixed seed, accelerated clock, exits when
the match completes:

```sh
BANANARC_AUTOTEST=1 godot --headless --path game
```

## Known slice limitations (vs the PRD)

- Gorillas are primitive placeholders — the Meshy retopo/texture/rig
  pipeline replaces the visuals, keeping this animation contract.
- Rooftop micro-obstructions (water tanks on play buildings) are decorative
  background only in the slice.
- No Game Center / async multiplayer / Daily Skyline yet; no audio pass.
- Buildings use flat PBR colors, not the scan-based material set.
- iOS/macOS export presets not committed yet (standard Godot export flow).
