# Deploying to TestFlight without a local Mac

The repo ships two GitHub Actions workflows:

| Workflow | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | every push / PR | Linux runner: imports the Godot project, runs the simulation smoke test and the AI-vs-AI full-match autotest. Needs nothing set up. |
| `.github/workflows/ios-testflight.yml` | manual (Run workflow) or a `v*` tag | macOS cloud runner: Godot iOS export → `xcodebuild` archive → signed IPA → TestFlight upload. Needs the one-time setup below. |

Once set up, shipping a build to your iPhone is: push a tag (or click
"Run workflow") → wait ~15 minutes → install from the TestFlight app.
No Mac is involved at any point; the macOS runner *is* your Mac.

---

## One-time setup

### 1. Apple Developer Program

Enroll at <https://developer.apple.com/programs/> ($99/year). Everything
below happens in the [developer portal](https://developer.apple.com/account)
and [App Store Connect](https://appstoreconnect.apple.com).

### 2. App ID and App Store Connect app

1. Portal → Certificates, Identifiers & Profiles → **Identifiers** → new
   **App ID**, e.g. `com.yourname.bananarc` (explicit, no wildcard).
2. App Store Connect → **My Apps** → **+** → New App → pick that bundle ID,
   platform iOS, any SKU.

### 3. Distribution certificate — no Mac required

Certificates are just a key pair; `openssl` on any machine works:

```sh
# Private key + certificate signing request
openssl genrsa -out dist.key 2048
openssl req -new -key dist.key -out dist.csr \
  -subj "/emailAddress=you@example.com/CN=Your Name/C=US"
```

Portal → **Certificates** → new **Apple Distribution** certificate →
upload `dist.csr` → download `distribution.cer`, then:

```sh
# Convert to the .p12 the workflow imports (pick a password; you'll store it as a secret)
openssl x509 -in distribution.cer -inform DER -out distribution.pem
openssl pkcs12 -export -inkey dist.key -in distribution.pem \
  -out distribution.p12 -legacy
```

(If your openssl lacks `-legacy`, omit it.) Keep `dist.key` and
`distribution.p12` safe and private.

### 4. Provisioning profile

Portal → **Profiles** → new **App Store Connect** distribution profile →
select your App ID and the distribution certificate → name it (e.g.
`Bananarc AppStore` — you'll store this exact name as a secret) →
download `bananarc.mobileprovision`.

### 5. App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** →
**App Store Connect API** → generate a **Team Key** with **App Manager**
role. Note the **Key ID** and **Issuer ID**, download the `.p8` once.

### 6. Repository secrets

GitHub repo → Settings → Secrets and variables → Actions → add:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | 10-char Team ID (portal → Membership) |
| `IOS_BUNDLE_ID` | e.g. `com.yourname.bananarc` |
| `APPLE_CERT_P12_BASE64` | `base64 -i distribution.p12` |
| `APPLE_CERT_PASSWORD` | the p12 export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i bananarc.mobileprovision` |
| `IOS_PROFILE_NAME` | the profile's exact name, e.g. `Bananarc AppStore` |
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | API Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8` |

The workflow's preflight step lists exactly which secrets are missing if
any are, so a misconfigured run fails in seconds, not minutes.

### 7. First deploy

Actions → **iOS TestFlight** → Run workflow (or `git tag v0.1.0 && git
push --tags`). When it finishes, the build appears in App Store Connect →
TestFlight (processing takes a few minutes), and installs on your iPhone
through the TestFlight app after you add yourself as an internal tester.

---

## When you *do* want an interactive Mac

CI covers build/sign/deploy entirely, but for occasional hands-on Xcode
work (simulator debugging, profiling with Instruments, first-run
screenshots) rent real Apple silicon by the hour:

- **Scaleway Apple Silicon** — M-series Mac mini, hourly billing, cheapest.
- **MacinCloud** — managed remote desktop, simplest to start.
- **MacStadium / OakHost** — dedicated monthly rentals.

Avoid Hackintosh/OSX-KVM images on generic VPSes — macOS licensing only
permits Apple hardware, and every legitimate provider above is exactly that.

## Apple TV

TestFlight exists on tvOS, so once a tvOS build exists, deployment is the
same shape as iOS: archive → upload → install from the TestFlight app on
the Apple TV. The blocker is upstream of us (PRD §15): **Godot has no
official tvOS export target**, so there is currently no native tvOS
binary to upload.

**Play on your Apple TV today — AirPlay.** The iOS TestFlight build gets
you couch play immediately:

1. Install the build on your iPhone/iPad from TestFlight.
2. Swipe into Control Center → Screen Mirroring → pick your Apple TV
   (same Wi-Fi network), or AirPlay from the app switcher.
3. Pair a game controller (Xbox/DualSense/MFi) to the *iPhone* —
   the game has full controller support: left stick = angle, right
   stick/triggers = power, D-pad = ±1 steppers, A = throw.

Latency is fine for a turn-based artillery game — nothing in Bananarc is
twitch-timed.

**Native tvOS — the plan, in order:**

1. **M0 spike** the community Godot tvOS port against 4.4; if it builds
   the slice, add a `tvos-testflight.yml` mirroring the iOS workflow
   (new App ID + tvOS provisioning profile, same certificate, same ASC
   API key — only two new secrets).
2. If the port isn't viable, evaluate patching Godot's iOS export to the
   `appletvos` SDK ourselves (iOS and tvOS share most of the toolchain;
   real engineering, weeks not days) or sponsoring upstream tvOS support.
3. Fallback per the PRD: ship iPhone/iPad/Mac at launch, Apple TV as a
   fast-follow — with AirPlay as the documented couch story until then.

The game code itself is already tvOS-shaped: controller input with a
discrete stepper path, 10-foot-legible HUD scaling, and no touch-only
interactions.

## Notes

- Build numbers auto-increment (`GITHUB_RUN_NUMBER`), so repeated uploads
  never collide; the marketing version lives in `game/export_presets.cfg`
  (`application/short_version`).
- The signed IPA is also attached to each run as a workflow artifact.
- macOS runner minutes bill at a 10× multiplier on private repos; a
  deploy run is roughly 10-15 minutes of wall clock.
- The same pattern extends to a Mac App Store build later (a second
  export preset + `xcodebuild` lane); tvOS remains gated on the Godot
  community port (PRD §15).
