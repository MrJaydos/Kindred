# Kindred — Project Memory

This file is loaded every session. It is the orientation and the standing rules. The full detail
lives in the imported specs below — read them before proposing or changing anything in their
domain. Keep this file short; put detail in the specs, not here.

## What Kindred is

A native mobile creature-raiser, spiritually descended from the old Digimon physical devices: the
player raises a single creature whose evolution is **earned from their real-world behavior** (phone
sensors), it can **permanently die** and leave a lineage, and the social layer is
**proximity-only** — two phones in the same room, no server.

## Non-negotiable pillars (never violate without explicit approval)

1. **Proximity-only, no server on the critical path.** Two players must be able to meet, battle,
   and use the roster with zero internet. Any server (the Coolify box) is an optional backstop
   only, behind the `RemoteBackstop` seam, no-op by default.
2. **Permadeath is real.** No revive, no paid continue. Death leads to a fresh, behavior-shaped
   creature plus a possible cumulative traited-egg head-start. See the evolution spec.
3. **Behavior shapes the creature.** Evolution is driven by real activity, not by spending or
   grinding. The creature is a portrait of how the owner lived.
4. **Transparent about data, mysterious about mechanics.** Honestly disclose what data is read and
   why (platform-required). Never expose *what it does* to the creature — no axes, thresholds, or
   rules in the player UI. Hidden numbers appear only in the dev-only debug overlay.
5. **Stats matter, but skill can overcome a moderate gap.** Battles are interactive; skill has a
   defined ceiling (`SKILL_CAP_OFFENSE`). Never make battles a pure stat-check or pure twitch race.

## Tech stack (fixed)

- iOS: **Swift + SwiftUI**. Android: **Kotlin + Jetpack Compose**. Two native codebases.
- **No cross-platform framework** (no Flutter / RN / Unity). No analytics SDKs.

## Standing engineering rules

- **Plan before coding.** Propose architecture, interface signatures, and file layout, then wait
  for approval. Build in small, reviewable steps.
- **iOS first**, then mirror the same architecture to Android. Don't start Android until the iOS
  prototype works end-to-end against mocks.
- **Everything risky sits behind an interface with a mock:** `BehaviorSource` (sensors),
  `PeerTransport` (NFC/BLE), `IntegrityChecker` (anti-cheat), `RemoteBackstop` (optional server).
  The whole app must be clickable on one device, in the simulator, with no hardware.
- **Config loads from the bundled local copy by default.** All tuning values in the specs' JSON
  blocks load locally; the remote-config seam may override later but is never required.
- **The cross-device path must be real even against a simulated opponent:** lockstep input
  exchange + per-exchange state-hash check + void-on-mismatch. Don't shortcut it for the prototype.
- **Sign save state** (Secure Enclave / Keystore) and clamp all sensor/input values at the
  interface boundary (plausibility bounds). Cheating should be costly and pointless, not blocked
  by a server.
- Real CoreMotion / HealthKit / Core Bluetooth / Core NFC (and Android equivalents) come in a
  later pass — interfaces + mocks for now, with platform purpose-strings stubbed as TODOs.

## Human-owned tuning knobs — do NOT "fix" these on your own

These are deliberate design dials, set to defaults in the specs. Surface them, don't silently
change them:

- **Lifespan / stage tempo** (currently slow, ~18–24 day lifespan).
- **Evolution legibility** (currently subtle — players should not crack the mapping instantly).
- **Skill-vs-stats ceiling** (`SKILL_CAP_OFFENSE`, currently 0.40).

## Source-of-truth documents

@kindred-claude-code-prompt.md
@kindred-evolution-mapping.md
@kindred-battle-resolution.md

> The evolution and battle specs are authoritative for their systems. If code and spec disagree,
> the spec wins — change the spec deliberately (with approval), don't drift the code away from it.
