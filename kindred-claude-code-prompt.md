# Claude Code Prompt — "Kindred" prototype

> Paste everything below the line into Claude Code as your opening message.
> It asks Claude Code to plan before coding, so review the plan it returns before letting it build.

---

## Project: "Kindred" — a creature-raiser where your real behavior shapes the monster

I'm building a mobile game called **Kindred**, spiritually descended from the old Digimon
physical devices but rebuilt for modern phones. Before writing any code, read this whole
brief, then **propose a plan and file structure and wait for my approval.** Do not start
coding until I say go.

### The concept (so your choices serve the design, not just compile)

- The player raises a single creature that has **no fixed species**. It hatches as a featureless
  blob and every evolution is **earned from the player's real-world behavior**, read off phone
  sensors. Walk a lot → lean and fast. Lots of late-night activity → nocturnal, twitchy, feral.
  Neglect it → it survives but grows **distant**, down a colder/harder-to-bond branch.
- **Permadeath is real and permanent.** No revive, no paid continue. Each new creature is a
  **fresh blob shaped by the player's own behavior in that life** — never a clone of the parent.
  But if the previous creature was **raised well and lived a full life**, it leaves a **traited
  egg** that gives the next generation a *faint, cumulative head-start* (a small boost toward
  reaching later stages). This mirrors the original Digimon "traited egg" mechanic: lives are
  fresh starts, but a well-raised bloodline compounds a subtle advantage across generations. A
  neglected or short life leaves an ordinary egg with no bonus.
- The social hook is **proximity-only, server-less battling**: two players physically near each
  other tap phones (NFC) to pair, then exchange battle state over Bluetooth LE. No accounts, no
  friend codes, no global ladder, no internet. Just "two phones in the same room."
- **Roster / local leaderboard (core social feature).** Every tamer you have *physically bumped*
  is saved to a persistent **Roster**: you can see them, their creature's current form and
  lineage, your head-to-head record, and where you rank among everyone you've met. The roster is
  fully **visual and browsable any time** — but every *action* (rematch, breed, trade) requires a
  **fresh physical bump**. The leaderboard is a trophy case of real-world encounters that can only
  grow in person. This is the heart of the game's social design: visible at all times, but it
  pulls you into the room to do anything with it.
- Tone of the design: stakes and honesty over engagement-farming. No notifications nagging,
  no streaks.

### Tech stack (non-negotiable)

- **iOS:** Swift + SwiftUI.
- **Android:** Kotlin + Jetpack Compose.
- Two native codebases. **No cross-platform framework** (no Flutter/RN/Unity).
- No backend, no server, no cloud, no analytics SDKs. Everything is on-device.

### Build order for THIS session (important — be realistic)

Building both platforms and all three systems at once is too much. Do it like this:

1. **Build iOS (SwiftUI) first** as the reference prototype.
2. Put **sensors behind a `BehaviorSource` interface** and the **cross-device link behind a
   `PeerTransport` interface**, each with a **mock implementation** so the entire app is
   clickable on a single device, in the simulator, with no real hardware.
3. Once the iOS prototype works end-to-end against mocks, **mirror the same architecture to
   Android (Compose)** — same model, same interfaces, Kotlin mock implementations.

Real CoreMotion / HealthKit / Core Bluetooth / Core NFC (and the Android equivalents) come in a
**later** session. For now, ship clean interfaces + mocks so the loop is fully playable.

### The three systems, at prototype fidelity

**1. Care + behavior-driven evolution loop (single-player core)**
- A `BehaviorSource` interface exposing daily signals: steps, active hours, time-of-day activity,
  and a "neglect" measure (time since last interaction). Provide a `MockBehaviorSource` with a
  few preset "lives" I can switch between (e.g. "Athlete", "Night Owl", "Neglected") plus manual
  sliders so I can drive evolution by hand in a debug panel.
- An evolution engine that maps accumulated behavior to a branching tree. At least 3 stages
  (blob → juvenile → adult) and at least 3 divergent adult branches (e.g. swift / feral /
  distant). Make the mapping data-driven and easy to tweak.
- **Legibility:** the game should NOT spell out "walking makes it fast." Players discover the
  mapping over time, like the original devices never explained themselves. Surface *what is
  happening* ("your creature is growing leaner") without surfacing *the rule that caused it*. The
  one exception is data transparency (see UX & permissions below) — be honest about what data is
  read, mysterious about what it does.
- Care actions (feed, clean, rest, play) that nudge stats. Keep it minimal but real.

**2. Proximity link (proof-of-concept, mocked transport)**
- A `PeerTransport` interface: `discover()`, `pairViaTap()`, `send(state)`, `receive()`.
- A `MockPeerTransport` that simulates an in-room opponent: tapping a "Bump phones" button
  pairs with a generated opponent creature and runs the exchange locally, so the whole flow is
  demonstrable on one device.
- Design the interface now so a real **NFC-tap-to-pair + BLE-to-exchange** implementation can
  drop in later without touching game logic. Add code comments noting that the real version uses
  open standards (BLE/NFC) specifically so iOS and Android can interoperate.
- **Roster + local leaderboard:** after a (mock) bump, persist the encountered tamer to a
  `Roster`. Build a browsable roster/leaderboard screen showing each met tamer, their creature,
  lineage, head-to-head record, and ranking. Crucially: rematch / breed / trade buttons are
  **disabled unless a fresh bump is active** — the roster is always *viewable* but never
  *actionable* without proximity. Make that gating explicit and obvious in the UI.

**3. Battle system (interactive, logic + UI)**
- Battles are **interactive and skill-driven**: live timing + paced mashing let a well-played
  creature overcome a *moderate* stat disadvantage, but skill has a defined ceiling so stats still
  matter. See the separate **Battle Resolution Spec** for the model, formulas, and config — treat
  it as the source of truth.
- **Deterministic given inputs, verifiable, no server:** both devices exchange per-exchange input
  summaries in lockstep over the (mock) transport, run the identical resolver on
  `(signed stats, shared seed, both input streams)`, and hash-check after each exchange — any
  mismatch voids the battle. This refines the "stats + seed" idea into an input-driven version
  that's still cheat-resistant.
- A clean vector battle UI showing the clash and outcome, and what each creature **carries away**
  (a small imprint nudge, win/loss to the Roster leaderboard). For the prototype, simulate the
  opponent's input stream locally so the full lockstep/hashing path runs end-to-end.

### Data model (shared concepts across both codebases)

- `Creature` (id, stage, trait vector, stats, birth/last-fed timestamps, lineage ref, win/loss).
- `Egg` — two kinds: a plain egg (no bonus) and a **traited egg** carrying a small cumulative
  evolution-bonus value earned only when the parent lived a full, well-cared-for life. The new
  creature still starts as a behavior-shaped blob; the traited bonus only nudges evolution odds.
- `Lineage` (ancestry chain + accumulated traited-bonus across generations).
- `Roster` / `MetTamer` (a tamer you've physically bumped: their display name, last-seen
  creature snapshot + lineage, head-to-head record, first/last met timestamps).
- Local persistence only: `UserDefaults`/`SwiftData` on iOS, `DataStore`/`Room` on Android.
  Keep it swappable.

### Integrity / anti-cheat (local-first, no live server required)

The game is server-less, so cheating is curbed with **on-device sanity checks**, not constant
validation. Build these in from the start:

- **Signed save state:** HMAC/sign the save with a key stored in the **iOS Secure Enclave /
  Android Keystore**, so a casual save-editor breaks the signature and the state is rejected.
- **Monotonic clock check:** detect time-travel / clock rollback used to fake elapsed care time.
- **Plausibility bounds:** cap how much behavior can move traits per real day; reject impossible
  inputs (e.g. tens of thousands of steps in a minute) at the `BehaviorSource` boundary.
- **Deterministic seeded battle:** both phones independently compute the result from a shared
  seed; mismatches void the battle, so editing stats mid-fight gains nothing.
- **Append-only hash-chained event log** for care/evolution, so tampering is detectable on bump.

For the prototype, stub these as a `IntegrityChecker` with simple working implementations and
comments on where the real Secure Enclave / Keystore signing goes.

### Optional server (Coolify) — strictly OFF the critical path

I have a Coolify server available, but the core loop must stay fully playable with it absent. If
useful, design clean optional hooks (behind a `RemoteBackstop` interface, no-op by default) for:

- **Opt-in encrypted lineage backup** so losing a *phone* doesn't erase a bloodline (the one
  genuinely sad failure of pure-local permadeath).
- **Occasional anti-cheat attestation** (validate signed receipts asynchronously).
- **Remote config** for the evolution table so balance can change without an app update.

Never make two players depend on the server to interact. Do NOT implement the server in this
session — just leave the interface seam.

### UX & permissions — transparent about data, mysterious about mechanics

Hold a clean split between two things:

- **Data transparency (mandatory, honest):** the app must clearly tell the player *what* it reads
  and *why*, because both platforms require it — iOS rejects vague HealthKit purpose strings, and
  Android Health Connect requires an in-context rationale plus a privacy policy. Plan for a clear
  permission-priming screen, e.g. "Kindred reads your steps, active energy, and active hours to
  grow your creature," with all processing on-device. For the prototype, build this priming
  screen against the mock (no real HealthKit/Health Connect yet) and add the iOS purpose-string
  keys (`NSHealthShareUsageDescription`, `NSMotionUsageDescription`, etc.) as TODO placeholders.
- **Mechanic mystery (the fun):** never explain *what the data does* to the creature. "We read
  your steps" is disclosed; "steps make it lean and fast" is discovered. Keep evolution rules out
  of the UI.

### Visual direction

- **Modern minimalist, clean vector.** Lots of whitespace, a restrained palette, crisp geometric
  shapes, smooth subtle motion. The creature itself should be assembled from simple vector
  primitives whose parameters shift with its traits (so "feral" vs "distant" reads visually
  without bespoke art). Define **design tokens** (color, spacing, type scale) up front and reuse
  them. Avoid skeuomorphism and avoid the retro-LCD look.

### Non-goals for this session (do NOT build these yet)

- Real Bluetooth / NFC / motion / health integration (interfaces + mocks only).
- The Coolify server implementation (leave the `RemoteBackstop` seam only).
- Account systems or any networking beyond the local mock.
- Monetization, onboarding flows, sound.
- The Android build, until iOS works against mocks end-to-end.

### What "done" looks like for this prototype

I can, on the iOS simulator, with no hardware:
1. Hatch a blob, pick/drive a behavior preset, and watch it evolve down a branch that visibly
   reflects that behavior — without the UI explaining the rule.
2. See a permission-priming screen that honestly states what data is read and why (mock-backed).
3. Tap "Bump phones" to battle a simulated in-room opponent, see a deterministic result, and have
   that tamer added to a browsable **Roster / leaderboard** whose rematch/breed/trade actions are
   greyed out until the next bump.
4. Let a well-raised creature die and receive a **traited egg** that gives the next generation a
   visible head-start, vs. a neglected creature leaving a plain egg.
…all behind clean `BehaviorSource` / `PeerTransport` / `IntegrityChecker` / `RemoteBackstop`
interfaces that real implementations can later replace.

### How to proceed

1. Ask me any clarifying questions you have now.
2. Propose: the architecture, the interface signatures, the file/folder layout, and the order
   you'll build in.
3. **Wait for my approval**, then build iOS-first in small, reviewable steps.
