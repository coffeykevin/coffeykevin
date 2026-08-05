# BANANARC

A premium reinterpretation of the 1991 QBasic classic **Gorillas**
(`GORILLA.BAS`) for iPhone, iPad, Mac, and Apple TV — same angle-and-velocity
soul, rebuilt with 3D assets, smooth side-on animation, an EGA-derived
palette, and a physics overlay that visually explains every throw.

## Contents

| Path | What it is |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Comprehensive product requirements document |
| [`docs/BRAND.md`](docs/BRAND.md) | Name shortlist, chosen brand, voice, colors |
| [`mockup/index.html`](mockup/index.html) | High-fidelity mockup: gameplay frame, physics overlay, art direction boards, platform layouts, brand boards |
| [`apple/`](apple/) | **Native Swift port (active development)** — SceneKit + SwiftUI, one codebase targeting iOS, tvOS, and macOS, so every Apple platform including Apple TV gets a real TestFlight build. Sim core in `apple/Core` with the same deterministic tests |
| [`game/`](game/README.md) | Playable Godot 4 vertical slice (reference implementation until the native port reaches parity) — classic physics, procedural obstruction skylines, nine-sky weather with real lighting, destruction, hot-seat + AI |

## The original

- Wikipedia: <https://en.wikipedia.org/wiki/Gorillas_(video_game)>
- Source (archival): [gist](https://gist.github.com/paulera/2525813cc3e5314c5932e1212a1d811b) ·
  [pmachapman/basic-samples](https://github.com/pmachapman/basic-samples/blob/master/QBASIC/GORILLA.BAS) ·
  [Internet Archive](https://archive.org/details/GorillasQbasic)

This project reinterprets the mechanics (trajectory equations, gravity 9.8,
quadratic wind drift, destructible skyline, two-number input) — it copies no
original code, art, or the "Gorillas" name.
