# BANANARC — Product Requirements Document

**A premium reinterpretation of QBasic Gorillas for iPhone, iPad, Mac, and Apple TV**

| | |
|---|---|
| Status | Draft v1.0 |
| Date | 2026-07-28 |
| Working title | **Bananarc** (see `docs/BRAND.md` for naming shortlist) |
| Platforms | iOS, iPadOS, macOS, tvOS (Universal Purchase) |
| Business model | Paid, premium ($4.99), no ads, no IAP at launch |

---

## 1. Vision

Two gorillas stand on the rooftops of a procedurally generated city and hurl
explosive bananas at each other. The player supplies exactly two numbers —
**angle** and **velocity** — and physics does the rest.

That loop, unchanged since *GORILLA.BAS* shipped inside MS-DOS 5 in 1991, is
still perfect. What has aged is everything around it: EGA graphics, keyboard
prompts, and a physics model the player could only learn by dying.

**Bananarc** is a faithful *reinterpretation*, not a port. We keep the exact
input model (angle + velocity), the wind, the gravity, the destructible
skyline, the smug sun, and the color world. We rebuild it with 3D assets,
smooth realistic animation viewed side-on, and — the signature feature — a
**physics overlay** that visually explains every throw, turning a nostalgic
artillery duel into something that quietly teaches projectile motion.

It should feel like a small, lovingly made premium game: the kind of thing
that justifies a few dollars the moment the first banana leaves a gorilla's
hand.

### Design pillars

1. **Two numbers, total mastery.** Angle and velocity are the whole input.
   No aim assist that plays for you; depth comes from reading wind and
   distance.
2. **Show the physics, don't hide it.** Every throw can be understood. The
   overlay explains *why* you missed, so improvement feels earned.
3. **1991 soul, 2026 craft.** EGA-derived palette, side-on view, chest-beating
   victory dance — rendered with modern 3D materials, lighting, and animation.
4. **Premium and respectful.** One price. No ads, no energy meters, no
   tracking. Works offline. Family-friendly.

---

## 2. Background: the original

*Gorillas* (`GORILLA.BAS`) was written in QBasic and distributed with MS-DOS 5
as a language demo. Reference material:

- Wikipedia: <https://en.wikipedia.org/wiki/Gorillas_(video_game)>
- Source code (archival copies):
  - <https://gist.github.com/paulera/2525813cc3e5314c5932e1212a1d811b>
  - <https://github.com/pmachapman/basic-samples/blob/master/QBASIC/GORILLA.BAS>
  - <https://archive.org/details/GorillasQbasic> (source + compiled)

### What the original actually does (from the source)

These are the mechanics we preserve. Constants below are taken from
`GORILLA.BAS` and are our ground truth for game feel:

- **Trajectory.** Per time-step `t`:
  - `x(t) = x₀ + v·cos(θ)·t + ½·(W/5)·t²`
  - `y(t) = y₀ − v·sin(θ)·t + ½·g·t²` (screen coordinates, scaled to screen height)
  - Wind is a *quadratic* horizontal drift, not a constant offset — long,
    slow lobs bend far more than flat fastballs. This is the core skill of
    the game and must be preserved exactly.
- **Gravity.** Default `g = 9.8`, player-configurable at match setup
  (the original allowed silly values; we keep this as "Moon / Earth / Jupiter"
  style presets plus a free slider in custom matches).
- **Wind.** `W = rand(10) − 5`, with a chance of gust amplification
  (`W ± rand(10)`). Displayed as a directional indicator whose length is
  proportional to strength. Re-rolled each round.
- **Input.** Angle in degrees (0–360 accepted; effective range ~0–90 mirrored
  for the right player), then velocity, entered as free numbers. We keep
  numeric entry as a first-class input alongside dial/slider controls.
- **City.** Procedural skyline: randomized building widths
  (`base + rand(base)`), heights following a random slope trend
  (upward / downward / valley / mountain), lit and unlit windows on a grid.
- **Destruction.** Banana impacts carve chunks out of buildings (circle
  removal in the original; volumetric chunk removal in ours). Craters persist
  for the whole match — the level *remembers* every miss.
- **The sun.** Anthropomorphic sun at top of screen; goes shocked (`O` mouth)
  when a banana flies through it.
- **Victory.** Direct hit on the opposing gorilla ends the round with an
  explosion and a chest-beating victory dance. First to N points (default 3)
  wins the match. Self-hits score for the opponent.

### What we are deliberately *not* doing

We reinterpret; we do not copy. No original code, sprite data, or the
"Gorillas" name ships in the product (see §15 Risks — the name has active
trademark conflicts anyway). The mechanics and constants above are game
rules — facts — and are re-implemented from scratch in Swift.

---

## 3. Goals & non-goals

### Goals

- G1. Ship a Universal Purchase premium title on iPhone, iPad, Mac, Apple TV.
- G2. Preserve the original's physics model and two-number input verbatim.
- G3. Add a physics overlay that makes every throw legible to a newcomer.
- G4. Local same-device multiplayer as the hero mode (the original was a
  couch game); strong solo AI; async online via Game Center.
- G5. 3D art with smooth, characterful animation at 60 fps (120 on ProMotion),
  in a side-on camera, using an EGA-derived palette.
- G6. Feel worth $4.99: polish, haptics, sound design, zero jank.

### Non-goals (v1)

- Real-time online multiplayer (async turn-based only at launch).
- Level editor / UGC.
- visionOS, watchOS, Android, Windows.
- Free-to-play economy of any kind.

---

## 4. Audience & market

- **Primary:** 30–50 year olds who played Gorillas / Scorched Earth / Worms;
  buy premium mobile games (Alto's, Mini Metro, Grindstone class).
- **Secondary:** Parents/teachers — the physics overlay makes it a legitimate
  "learning by stealth" purchase; couch play on Apple TV and iPad.
- **Positioning:** "The artillery duel from your first PC, rebuilt like a
  Pixar short." Nostalgia is the hook; the overlay and match feel are why it
  gets recommended.
- **Price:** $4.99 launch (tier flexible per region). Universal Purchase
  across all four platforms is a headline feature. Possible paid cosmetic
  city-theme packs post-launch; never gameplay-affecting.

---

## 5. Platforms & requirements

| Platform | Min OS | Notes |
|---|---|---|
| iPhone | iOS 17 | Landscape primary; portrait supported with stacked HUD |
| iPad | iPadOS 17 | Same-device 2P is the showcase; pointer + Apple Pencil hover supported |
| Mac | macOS 14 | Native (not Catalyst-only feel): resizable window, keyboard-first entry, menu bar |
| Apple TV | tvOS 17 | Couch multiplayer focus; Siri Remote + game controllers |

- One codebase, Universal Purchase, iCloud sync of profiles/stats/unlocks.
- 60 fps floor on A14/M1-class devices; 120 fps on ProMotion.
- Full offline play (online only needed for async matches/leaderboards).

---

## 6. Core gameplay

### 6.1 The loop

1. **Round start.** City generates (or persists mid-match), wind rolls,
   gorillas take their rooftops, turn banner shows whose go it is.
2. **Aim.** Active player sets **Angle** (0–90°, mirrored for right player)
   and **Power** (0–100, mapping linearly onto the classic velocity range so
   the original's numbers still transfer). Inputs:
   - The bottom control bar: segmented Power meter (yellow) and Angle meter
     (cyan) flanking a central circular **FIRE** button; drag the meters or
     use ± steppers.
   - Type exact numbers (tap the readout → numeric pad; always available —
     this is sacred to the original; classic velocity values accepted).
   - Previous shot's values are pre-filled, exactly like the original's
     muscle-memory iteration loop.
3. **Throw.** The gorilla **throws the banana by hand** — full
   anticipation-windup-release animation with real weight shift; the banana
   leaves the hand at the configured angle/power, spinning end-over-end
   (the original's 4-frame rotation, now continuous). No weapons, no
   launchers — bare-handed, exactly like 1991.
4. **Flight.** Camera stays locked side-on (no cinematic cuts — readability
   first). Banana arcs under gravity + wind. Sun reacts if crossed.
5. **Resolution.**
   - **Building hit:** volumetric crater blast, debris, dust; crater persists.
   - **Gorilla hit:** slow-motion beat → explosion → surviving gorilla's
     chest-beat victory dance → score tick.
   - **Off-screen:** whistle-away, wind sock waggles as a hint.
6. **Overlay moment (see §7).** After resolution, the throw's actual
   trajectory stays ghosted on screen with its physics breakdown until the
   next player commits their aim. Compare-and-adjust is the learning loop.
7. Alternate turns until a hit; first to N points (default 3, configurable
   1–9) wins the match.

### 6.2 Physics spec (deterministic)

- Fixed-timestep custom integrator replicating the original equations
  (§2) — **not** the engine's physics solver. Reasons: exact classic feel,
  perfect determinism for async multiplayer + replays, and trivially
  serializable throws (`{seed, angle, velocity}` fully describes a round).
- Gravity presets: Moon 1.6 / Earth 9.8 (default) / Jupiter 24.8 / custom
  slider 1–30.
- Wind per original: `rand(10)−5` with gust amplification chance; a
  "Calm skies" toggle for teaching mode. Optional "Weather wind" setting
  couples the roll's distribution to the round's weather condition (§9),
  always within the classic bounds; off by default.
- Collision: signed-distance field over the destructible skyline; banana is a
  point with small radius, gorillas have generous-but-fair capsule hitboxes.

### 6.3 Modes

| Mode | Description |
|---|---|
| **Hot-Seat Duel** | Two players, one device. Pass-and-play on iPhone; split-HUD on iPad/Mac/TV. The hero mode. |
| **Solo vs. AI** | Three AI tiers: *Banana* (random-ish with drift), *Silverback* (converges like a human, 2–4 throws), *Newton* (near-optimal, reads wind, occasional deliberate miss for fairness). AI "thinks" visibly — its dial moves, it hesitates. |
| **Async Online** | Game Center turn-based matches. Because a throw is just `{seed, angle, velocity}`, each turn replays deterministically on the opponent's device. |
| **Daily Skyline** | One shared seeded city + wind per day; fewest total throws to win 3 rounds vs. Newton AI; global leaderboard. |
| **Practice Range** | Free throwing with the full overlay always on, wind dial-a-value, slow-motion scrubber. This is the "physics classroom" mode. |

### 6.4 Match & meta

- Match settings: points to win, gravity preset, city size (5–12 buildings),
  wind (off/normal/wild), round timer (off/30s/60s for hot-seat banter).
- Stats: accuracy, average throws-to-hit, longest hit, wind-corrected hits.
- Achievements: "Through the Sun", "One-Throw Wonder", "Skyscraper Surgeon"
  (win without destroying a building), "Moonshot" (hit at gravity ≤ 2), etc.
- Unlockable cosmetics via play (not purchase): city palettes (all
  EGA-derived), banana trails, gorilla scarves. Small, tasteful, premium.

---

## 7. The Physics Overlay (signature feature)

The original taught by punishment. We teach by *showing*. The overlay has
three moments, all skippable/toggleable for purists ("Classic mode" = none).

### 7.1 While aiming — the Intent readout

- From the gorilla's hand: the **launch vector** drawn as an arrow whose
  direction = angle and length ∝ velocity.
- The vector decomposes live into faint **v·cosθ** (horizontal) and
  **v·sinθ** (vertical) component arrows with numeric labels.
- A short **ghost arc** shows the *windless* first ~20% of the trajectory —
  enough to communicate the shape, never the landing point (no aim assist).
- The **wind ribbon** along the top shows direction and strength; while
  aiming, a subtle animated drift on the ghost arc's tip hints how much this
  wind will matter *at this velocity* (drift scales with flight time, which
  is the original's deep lesson).

### 7.2 During flight — the live trace

- The banana draws a thin dotted trace behind it (classic!), colored by the
  thrower.
- Optional (on by default first sessions): tangent velocity arrow on the
  banana, shrinking vertically as it rises, flipping at apex — apex gets a
  small "0 ↑" tick, the single clearest projectile-motion teaching beat.

### 7.3 After resolution — the Debrief

- The full actual trajectory stays ghosted until the next throw is committed.
- Tapping/focusing it opens the **Debrief card**: angle, velocity, flight
  time, apex height, horizontal distance, and — crucially — **wind drift**:
  a bracket showing where the banana *would* have landed with no wind vs.
  where it did. "Wind cost you 14 m" is the sentence that makes players
  feel the model.
- Both players see the opponent's last trace (as in the original, where the
  dotted line persisted) — reading your rival's misses is part of the duel.

### 7.4 Learn mode (Practice Range)

- Slow-motion scrubber over a throw with the component arrows animating.
- Three 90-second interactive vignettes: *Angle vs. distance* (45° optimum,
  windless), *Why wind bends lobs more*, *Gravity presets*. Written for a
  curious 10-year-old; never gates gameplay.

---

## 8. Controls per platform

| Platform | Aim | Fine-tune | Throw | Notes |
|---|---|---|---|---|
| iPhone/iPad | Drag aim dial / drag back from gorilla (slingshot-style maps to angle+velocity) | Tap readouts → numeric keypad; ± steppers | Big THROW button; haptic detents at 5° / 5 v | Slingshot drag always shows the two numbers changing — the numbers are the truth |
| Mac | Mouse drag on dial, scroll wheel fine-tune | **Type numbers directly, Tab between fields, Return to throw** — the 1991 ritual, first-class | Return | Full keyboard play; menu bar match controls |
| Apple TV | Siri Remote: swipe ring for angle, click-pad edges for velocity; or gamepad sticks | D-pad steppers | Play/Pause or A | Oversized HUD; readouts legible at 3 m |
| Any | Game controllers (MFi/Xbox/DualSense): left stick angle, triggers velocity, A to throw | D-pad ±1 | A | Rumble on impact |

Accessibility: every control has a discrete stepper path (no
gesture-only inputs); see §13.

---

## 9. City, camera & presentation

- **Camera & dimensionality:** the scene is **truly three-dimensional** — a
  full 3D city with real depth, rendered through a perspective camera
  holding the classic side-on framing (long lens, so the silhouette still
  reads as Gorillas). Buildings are volumes at staggered depths: gameplay
  buildings sit on the throw plane, non-play towers fill lanes in front of
  and behind it, all shifting in true parallax as the camera breathes.
  Gentle push-in on resolution moments only; the frame never cuts during
  flight.
- **Gameplay plane:** the simulation remains exactly the classic 2D model
  (§2) evaluated on a single vertical plane through the city. Only
  buildings on that plane collide; depth is presentation. This keeps 1991
  physics intact inside a fully dimensional world.
- **Rendering target:** photoreal **New-York-inspired city under a dynamic
  weather and lighting system**, per the approved concept art. Filmic tone
  curve and fine grain throughout. The classic EGA palette survives as the
  UI accent system and as the unlockable "CGA Dream" skin.
- **Weather & time-of-day system (randomized per round):** each round rolls
  a condition and a clock time from the match seed (deterministic, so async
  opponents see the identical sky). Nine launch conditions, per concept:

  | Condition | Reference time | Lighting notes |
  |---|---|---|
  | Clear Day | 2:00 PM | High sun, crisp shadows, blue sky, white cumulus |
  | Cloudy | 3:15 PM | Flat grey diffuse light, muted palette |
  | Rain | 4:50 PM | Streaking rain, wet-roof specular, misted distance |
  | Storm | 5:30 PM | Near-dark, ambient lightning strikes, wild cloud deck |
  | Sunset | 7:45 PM | Ember sky, silhouetted skyline, warm rim light |
  | Clear Night | 11:30 PM | Star field, lit windows dominant, cool moonlight |
  | Morning | 6:30 AM | Low gold sun disc, long soft shadows, amber haze |
  | Foggy | 8:10 AM | Heavy fog, skyline dissolves with distance |
  | Snow | 9:20 AM | Falling snow, accumulation on parapets and rooftops |

  Rules: weather is **presentation-first** — the physics model never changes.
  The only permitted gameplay coupling is an optional "Weather wind" match
  setting that skews the classic wind roll's distribution to fit the sky
  (storm → wilder rolls, calm day → milder) while staying strictly within
  the original bounds; off by default. Fog and rain reduce *visual* contrast
  of the far skyline, never hit detection. Lightning and snow accumulation
  are ambient. The HUD always states condition and time (e.g. "STORM ·
  5:30 PM") so variance reads as a feature, not a bug.
- **Skyline — different on every load, and part of the game:** the city on
  the throw plane is regenerated from a fresh seed every round (and every
  app load), per the §2 rules — randomized widths, heights following a
  rolled slope profile (upward / downward / valley / mountain), varied
  materials. No two duels play the same.
  - **Subtle obstructions by design:** the generator guarantees at least
    one "interceptor" — a mid-city building (or its water tower, chimney,
    or antenna) tall enough to clip the lazy 45° lob between the two
    rooftops — so players must *shape* throws, not just bisect the screen.
    Micro-obstructions (water tanks, parapets, rooftop sheds) add ±small
    variance at crest heights; they're destructible like everything else.
  - **Solvability guarantee:** after generation, the deterministic
    integrator sweeps the angle/power space; the layout is accepted only if
    both players retain multiple viable trajectory families in calm wind.
    Reject-and-reroll is invisible and instant.
  - **Distinctness check:** consecutive rounds must differ meaningfully
    (skyline-profile distance metric) so "new city every round" is felt,
    not just true.
- **Staging in depth:** around the throw plane, non-play lanes complete the
  city — a hazy backlit landmark layer (Empire-State-class spire, distant
  towers), mid lanes of tenement rooftops with chimneys and trestle water
  towers, and near-foreground silhouettes. Fully modeled volumes,
  scan-derived masonry, normal-mapped brick, cornice and fire-escape
  detail.
- **Destruction:** volumetric chunk removal with persistent craters exposing
  interior floors (desks, a sad water cooler — one readable gag per interior,
  never noisy).
- **Backdrop:** driven by the weather system above — one skyline, nine
  skies. The classic sun-with-a-face (**Sol**) lives in the "CGA Dream"
  cosmetic skin and as an easter egg (flying a banana through the sun or
  moon's screen position in any sky still triggers a hidden reaction) —
  the photoreal skies themselves stay clean.
- **Gorillas:** two hero characters, **Kilo** (left, signal-yellow accents)
  and **Newton** (right, signal-cyan accents), matching the HUD's Power and
  Angle colors. Built from the Meshy "Polygonal Gorilla" base mesh,
  realistically textured and fully animated (pipeline in §12): 4K PBR skin
  and fur maps over the retopologized base, shell-fur shading tiered by
  device, subsurface on muzzle and palms. They **throw bananas bare-handed**
  from a powerful standing windup — no weapons. Fur and rim light respond
  to the active weather (golden rim at sunset, wet matting in rain, snow
  dusting in winter rounds). Animation set: idle sway + knuckle taps,
  windup-throw with full weight shift, duck/flinch on near-miss, defeat
  ragdoll-to-sit, and the sacred **chest-beat victory dance** —
  motion-designed, 3 escalating loops.

Full art direction with mockups: `mockup/index.html`.

---

## 10. Audio direction

- **Music:** minimal — a warm synth bed on menus quoting the original's
  victory jingle interval structure (re-composed, not sampled); silence +
  city ambience during aim (tension), music sting on hits only.
- **SFX:** banana whoosh with doppler; deep sub-thump explosions (per-crater
  debris tinkle); gorilla vocalizations (recorded percussion + processed
  grunts, no real gorilla samples needed); sun "gulp" when overflown.
- **Haptics (iPhone/gamepad):** dial detents, windup rumble ramp, sharp
  transient on impact, victory dance thumps.

---

## 11. Screens & flow

1. **Title:** skyline vista, gorillas idle, one banana lazily arcs across.
   Play / Modes / Practice / Settings.
2. **Match setup:** players (hot-seat names, exactly like the original's
   name prompts), points to win, gravity, wind, city size.
3. **In-game (per approved concept):** dark-charcoal HUD floating over the
   scene — condition + time label top-left ("STORM · 5:30 PM"), menu button
   and emote/chat button in the top corners; full-width bottom bar reading
   **PLAYER 1 · POWER · WIND · ANGLE · PLAYER 2**: player names in their
   colors (yellow/cyan) with score pips at the ends, segmented POWER meter
   (0–100) and ANGLE meter (0–90), and the wind readout ("WIND → 23 MPH")
   at dead center. Readouts are tappable for typed entry; the throw itself
   fires from the active gorilla (tap-and-hold the gorilla, Return on Mac,
   A on controller) so the bar stays symmetric.
4. **Debrief overlay** (§7.3) between throws.
5. **Match end:** victory dance stage, stats card (accuracy, best throw,
   wind drama), rematch / swap sides / done.
6. **Settings:** overlay verbosity (Full / Minimal / Classic-off), haptics,
   colorblind trajectory palette, left-handed HUD, reduced motion.

---

## 12. Technical approach

### Engine: Godot 4

The game is built on **Godot Engine** (<https://godotengine.org>),
Godot 4.x:

- **Rendering:** Forward+ with the native **Metal** rendering backend on
  Apple platforms (Godot 4.4+); one fully 3D scene viewed through a
  perspective camera in the classic side-on framing; the weather system
  (§9) implemented as a `WorldEnvironment` + custom sky shader driven by
  the round's condition and clock time.
- **Real lighting & shaders (no faked light):** a physically-driven
  `DirectionalLight3D` sun/moon positioned from the round's clock time,
  casting real cascaded shadow maps across the skyline; real-time GI —
  SDFGI on Mac/high-tier devices, baked lightmap GI + SSAO on mobile
  tiers — so lit windows, craters, and explosions actually illuminate
  their surroundings; volumetric fog for the Foggy/Rain/Storm conditions;
  SSR-based wet-roof reflections in rain; explosion flashes as transient
  omni lights with shadow. Custom Godot shaders: sky rig, shell fur,
  wet/snow surface response, SDF-driven crater cutaways, heat-shimmer on
  explosions. Every material is PBR; nothing is painted into textures that
  the light rig should be doing.
- **Language:** GDScript for game/UI flow; the deterministic simulation
  core (below) in a typed, engine-independent module (GDScript with typed
  arrays or C# — decide in M0) so replays never touch engine physics.
- **Determinism:** unchanged from prior spec — integer-seeded PRNG for
  city/wind/weather; fixed-timestep integrator; throw =
  `{matchSeed, roundIndex, angle, power}` → identical replay everywhere
  (enables async MP, replays, Daily Skyline). **Godot's physics engine is
  not used for the banana** — it renders what our integrator computes.
- **Destruction:** SDF texture per skyline; crater = sphere subtraction;
  mesh chunks are cosmetic, gameplay collision reads the SDF (compute
  shader or CPU fallback).
- **Apple services:** Game Center (turn-based matches, leaderboards,
  achievements) and StoreKit via Godot iOS/macOS plugins
  (godot-ios-plugins / GodotApplePlugins); iCloud key-value sync for
  profiles/stats. Budget M0 time to validate plugin coverage on macOS.
- **Exports:** official Godot export templates for iOS (iPhone/iPad) and
  macOS. **tvOS is not an official Godot export target** — see Risks §15;
  plan A is the community tvOS port validated in M0, plan B ships
  iPhone/iPad/Mac at launch with Apple TV following.
- **No third-party analytics SDKs; no tracking.** Privacy nutrition label:
  "Data Not Collected." That's marketing.
- **Performance budget:** < 400 MB install; < 3 s cold launch to title;
  60 fps floor during explosions on A14.

### Gorilla asset pipeline

The gorillas are built from a licensed base mesh, textured realistically
and fully animated:

1. **Base mesh:** Meshy "Polygonal Gorilla"
   (<https://www.meshy.ai/3d-models/Polygonal-Gorilla-019f8b52-7ff1-71db-aa57-97ee9de2e59c>),
   exported as GLB/FBX. Verify the Meshy plan's commercial-license terms
   before production (open question §17).
2. **Cleanup & retopo (Blender):** weld/manifold pass, quad retopo to a
   game budget (~15–25k tris LOD0, plus LOD1/LOD2), clean UV atlas. The
   faceted silhouette is smoothed only where deformation needs it
   (shoulders, hips); the model's strong shape reads are kept.
3. **Realistic texturing:** 4K PBR set — albedo, normal (baked from a
   sculpted detail pass: fur clumps, skin folds, knuckle callus), roughness,
   AO — with subsurface maps for muzzle, ears, palms. Fur rendered as
   **shell-fur shader** in Godot (8–16 shells by device tier) plus
   fin cards on the silhouette; wet/snow variants are shader parameters
   driven by the weather system, not extra textures.
4. **Rig & animation (Blender):** custom control rig (IK arms/legs, spine,
   jaw, brow), skinned and exported as one GLB with the full clip set from
   §9: idle loop, windup-throw (angle-tracking via an additive aim layer),
   near-miss flinch, defeat, 3-loop victory dance, plus turn-face and
   emote hooks. Root-motion-free; all clips loop- or tail-clean.
5. **Godot import:** GLB → `AnimationTree` (state machine + blend spaces);
   Kilo and Newton share the mesh with per-character material tint
   (yellow/cyan accents) and animation timing offsets so they never move
   in sync.

---

## 13. Accessibility

- All gesture inputs have stepper/typed equivalents (§8).
- VoiceOver: full HUD labeling; throw results announced ("Hit building,
  12 meters short, wind drift 4 meters left").
- Trajectory/wind colorblind-safe palette option (shape + dash patterns
  differentiate players, never color alone).
- Dynamic Type on all non-diegetic UI; tvOS 3-meter legibility pass.
- Reduced motion: no screen shake, cut push-ins, keep information overlays.
- Optional round timers off by default (no time pressure).

---

## 14. Success metrics

- 4.7★+ App Store rating sustained after 5k ratings.
- Editorial feature (premium indie slots) in ≥ 1 storefront region.
- Attach: ≥ 25% of buyers play a hot-seat match in week 1 (couch DNA works).
- ≥ 40% of new players complete one Practice Range vignette (overlay lands).
- Refund rate < 1%.

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| **Naming/trademark:** "Gorillas" conflicts (delivery brand, Nintendo adjacency) | Ship as **Bananarc** (clearance search required); market as "inspired by the classic 1991 artillery duel" without using the original name in the title |
| Physics feels "off" vs. memory | Golden-file tests replaying known original throws; beta with Gorillas veterans; keep constants exactly per §2 |
| Two-number input feels dated to newcomers | Slingshot drag maps to the same two numbers; overlay makes them meaningful; Practice Range onboards |
| tvOS input precision | Discrete steppers + detents; oversized readouts; tested at 10-foot distance |
| **Godot has no official tvOS export** | **Spike done (Aug 2026): no viable path today.** The community port ([godotengine/godot#45829](https://github.com/godotengine/godot/pull/45829)) was Godot 3.x-only, never merged, unmaintained; Godot 4 tvOS remains an open unimplemented proposal ([godot-proposals#13532](https://github.com/godotengine/godot-proposals/issues/13532)). Decision: launch iPhone/iPad/Mac with AirPlay as the Apple TV story; track/encourage the upstream proposal; re-evaluate a Unity port only if native tvOS becomes a hard business requirement (the engine-independent sim core keeps that port bounded) |
| Godot Apple-services plugin coverage (Game Center turn-based, StoreKit, iCloud on macOS) | M0 spike on godot-ios-plugins / GodotApplePlugins; fall back to a thin native plugin we write ourselves — the API surface we need is small |
| Meshy base-mesh license terms | Confirm the account's plan grants commercial use of the Polygonal Gorilla asset before production; budget a from-scratch sculpt as fallback (the retopo/texture/rig pipeline is identical) |
| Async MP cheating (client-authoritative) | Determinism means opponent's device re-simulates every throw; divergence = flag |

---

## 16. Milestones

| Phase | Duration | Exit criteria |
|---|---|---|
| **M0 Prototype** | 4 wks | Godot grey-box: classic physics + typed input + destruction on iPhone; feel sign-off vs. original side-by-side; spikes on tvOS community export and Game Center/StoreKit plugins; Meshy license confirmed |
| **M1 Vertical slice** | 8 wks | One polished city, final gorillas + animation set, overlay v1, hot-seat mode, haptics/sound pass |
| **M2 Feature complete** | 8 wks | All modes, 4 platforms, Game Center, accessibility pass |
| **M3 Polish & beta** | 6 wks | TestFlight (incl. Gorillas-veteran cohort), perf budget met, localization (EN/DE/FR/ES/JA/PT) |
| **M4 Launch** | 2 wks | Universal Purchase live, press kit, launch trailer (windup → overlay explain → chest-beat) |

---

## 17. Open questions

0. Meshy asset license: confirm commercial-use rights for the Polygonal
   Gorilla base mesh under the account's plan tier; record the license in
   the repo before any store submission.
1. Final name clearance (legal search on Bananarc + shortlist, `BRAND.md`).
2. Round timer default for hot-seat — playtest banter vs. pace.
3. Do craters persist across *rounds* within a match (original: new city per
   round) — proposal: persist within round only, new city per round, with a
   "Ruins mode" toggle that persists all match. Playtest.
4. Cosmetic DLC pricing/timing post-launch.
5. macOS: also ship on Steam later? (Out of scope v1, keep door open.)
