# Kindred — Evolution Mapping Spec

> **Audience: the engine and the developer, never the player.** None of the labels, thresholds,
> axes, or rules in this document should appear in the UI. Players discover effects; they never
> see the table. Feed this file to Claude Code alongside the main prompt so the evolution engine
> is built against concrete values rather than guesses. Every number here is a **tunable default**,
> not sacred — the point is to pin the *structure* and give sane starting points.

---

## 1. Design goals this table serves

- A creature is a **portrait of how its owner actually lived** during its life.
- The mapping must be **legible in hindsight but opaque in advance** — a player who walked a lot
  and sees a lean, fast creature can *infer* the link, but the game never states it.
- Outcomes are **deterministic given the inputs** (so battles/seeds replay identically and the
  same life reliably yields the same creature), with no hidden randomness except an explicit,
  seeded "wildcard" allowance.
- Faithful to the original Digimon spine: **care mistakes gate higher forms**, **most stats reset
  each evolution**, **win ratio gates the apex**, and a **well-raised full life leaves a cumulative
  "traited egg."**

---

## 2. Raw signals → normalized inputs

Signals come from the `BehaviorSource` interface (health/motion) and from in-app care. Each is
normalized to a daily 0–100 score before it touches traits. Clamp every input — see the
plausibility bounds in the integrity layer.

| Signal | Source | Normalized as | Notes |
|---|---|---|---|
| `steps` | Health/motion | 0 steps → 0, ~12k steps → 100 (linear, clamp) | Drives Vigor |
| `activeEnergy` | Health | kcal vs personal rolling baseline → 0–100 | Drives Vigor |
| `nightActivityShare` | Motion timestamps | % of day's activity in 23:00–04:00 → 0–100 | Drives Nocturnality |
| `sleepRegularity` | Health/sleep | variance of sleep-onset time, low variance → high score | Drives Discipline |
| `interactionCount` | In-app | care actions taken today vs target → 0–100 | Drives Bond |
| `responseLatency` | In-app | how fast the player answers "calls" → 0–100 | Drives Bond |
| `careMistakes` | In-app | count of missed calls this stage (NOT 0–100; a raw counter) | Gates + penalties |

**Care mistake definition (Digimon-faithful):** when a need (hunger, energy, sleep) goes unmet, a
**call** fires. If unanswered within the **call window** (default 15 min) the call lapses and a
care mistake is recorded. Care mistakes **reset on each evolution**. Poop/illness/overfeed are
*not* care mistakes but feed separate minor penalties.

---

## 3. Trait axes (the creature's accumulating "self")

Four continuous axes, each 0–100, accumulated across the creature's whole life as a
**time-weighted running mean** of the daily inputs feeding them (recent days weighted slightly
higher so a changed lifestyle can still bend an older creature). Plus one derived axis.

| Axis | Fed by | Meaning |
|---|---|---|
| **Vigor** | `steps`, `activeEnergy` | Physical, athletic, fast |
| **Nocturnality** | `nightActivityShare` | Wakeful at night, restless, feral |
| **Bond** | `interactionCount`, `responseLatency` | Attached, trusting, warm |
| **Discipline** | `sleepRegularity`, low `careMistakes` | Ordered, steady, stalwart |
| **Neglect** *(derived)* | inverse of Bond + accumulated `careMistakes` | Override toward the cold line |

Per-day movement on any axis is **capped** (default ±6 points/day) so no single day rewrites a
creature and so impossible inputs can't spike it. This cap is also an anti-cheat boundary.

---

## 4. Stage timeline

Real-world-time gated, paused while the creature sleeps (Digimon-faithful). Times are the primary
**emotional-tempo knob** — shorten for a fast, disposable-stakes feel; lengthen to make each
creature precious.

| Stage | Name (internal) | Reached at | Branches? | Notes |
|---|---|---|---|---|
| 0 | `egg` | t = 0 | no | Hatches after ~1 min, like the originals |
| 1 | `blob` | ~1 min after hatch | no | Warm-up. **Nothing the player does matters yet.** |
| 2 | `juvenile` | ~ day 1 | soft | First divergence: an *early-lean* sub-form from the strongest axis so far |
| 3 | `adult` | ~ day 3–4 | **yes** | Main branch selection (Section 5) |
| 4 | `apex` | ~ day 7+, gated | yes | Hard to reach; see Section 6 |
| — | natural death | ~ day 18–24 | — | Full lifespan; only then can a traited egg form |

Death can also come **early** from sustained neglect (e.g. ≥ 20 cumulative care mistakes, or a
need left empty > 12 h) — an early death cannot leave a traited egg.

---

## 5. Adult branch selection (Stage 2 → 3)

Resolved **once**, deterministically, at the transition. Evaluate in this strict priority order
(first match wins) to avoid ties:

1. **Neglect override → `DISTANT`.** If `Neglect ≥ 70` OR `careMistakes ≥ 8` this stage → the cold
   branch. (It still *survives* — distance is a personality, not a failure state.)
2. **Dominant axis → matching branch.** Take the highest of {Vigor, Nocturnality, Bond, Discipline}.
   If it is `≥ 55` **and** at least `12` points above the second-highest, pick its branch:
   - Vigor → `SWIFT`
   - Nocturnality → `FERAL`
   - Bond → `BONDED`
   - Discipline → `STALWART`
3. **No clear dominant axis → `DRIFTER`** (the common/balanced fallback — unremarkable but healthy).

**Seeded wildcard (optional, default off):** with probability `wildcardChance` (default 0.05),
using the creature's seed, allow one branch "slip" to an adjacent line. Keep it off for the
prototype so behavior is fully legible during testing.

### Branch → form summary

| Branch | Vibe | Visual cue (vector params) | Battle bias |
|---|---|---|---|
| `SWIFT` | lean, quick, eager | elongated, sharp angles, light | high speed, low HP |
| `FERAL` | nocturnal, twitchy, wild | spiky, asymmetric, dark palette | high attack, erratic |
| `BONDED` | warm, loyal, expressive | rounded, soft, open posture | balanced, high stamina |
| `STALWART` | composed, sturdy, ordered | symmetric, broad, grounded | high HP, low speed |
| `DISTANT` | cold, aloof, self-contained | angular, muted, closed posture | high defense, low bond effects |
| `DRIFTER` | ordinary, adaptable | neutral midpoint of all params | even stats |

---

## 6. Apex stage (Stage 3 → 4) — hard gate

Faithful to Perfect/Ultimate requirements. To reach `apex`, ALL must hold at the evaluation window:

- The creature stayed in `adult` form for at least the apex timer (default 72 h awake).
- **Care mistakes this stage ≤ 2.**
- **Battle win ratio ≥ 0.70** over the last 15 battles (if fewer than 15 battles, apex is locked).
- The branch's dominant axis remained `≥ 60`.

The `DISTANT` line has a **parallel cold apex** reachable *without* the win ratio or low-care-mistake
gates (its path rewards a different kind of life) — so neglect has its own terminal form, not just
a dead end. Everything else falls back to a "late adult" form, not a failure.

---

## 7. Traited egg (cross-generation inheritance)

On death, decide the egg:

- **Plain egg** (no bonus) if the creature died early, or never reached `adult`, or had high
  cumulative care mistakes.
- **Traited egg** if the creature **lived past its natural lifespan after its last evolution** AND
  reached at least `adult` AND kept lifetime care mistakes low (default ≤ 4). Bonus scales with the
  stage reached: `adult → +1`, `apex → +2` (internal "boon" points).

**Cumulative across the bloodline.** The new creature inherits `Lineage.boon = parentBoon +
thisLifeBoon`, capped (default cap 6). Each boon point grants a small head-start: e.g. `+5%`
toward clearing each evolution gate, and a tiny starting nudge (≤ 3 pts) on the parent's dominant
axis — enough to *tilt*, never enough to *predetermine*. The new life is still a fresh
behavior-shaped blob; the boon only loads the dice slightly. `apex`/terminal status itself is
**not** inherited (you must earn it each generation).

---

## 8. Machine-readable config (engine loads this)

```json
{
  "version": 1,
  "signals": {
    "steps":            { "feeds": "vigor",        "norm": { "type": "linear", "in": [0, 12000], "out": [0, 100] } },
    "activeEnergy":     { "feeds": "vigor",        "norm": { "type": "baselineRatio", "out": [0, 100] } },
    "nightActivity":    { "feeds": "nocturnality", "norm": { "type": "share", "window": [23, 4], "out": [0, 100] } },
    "sleepRegularity":  { "feeds": "discipline",   "norm": { "type": "invVariance", "out": [0, 100] } },
    "interactionCount": { "feeds": "bond",         "norm": { "type": "ratioToTarget", "target": 6, "out": [0, 100] } },
    "responseLatency":  { "feeds": "bond",         "norm": { "type": "invLatency", "goodMs": 60000, "out": [0, 100] } }
  },
  "traits": {
    "axes": ["vigor", "nocturnality", "bond", "discipline"],
    "accumulation": "timeWeightedMean",
    "recencyHalfLifeDays": 5,
    "maxDailyDelta": 6
  },
  "careMistakes": {
    "callWindowMinutes": 15,
    "resetOnEvolution": true,
    "earlyDeathThreshold": 20,
    "emptyNeedDeathHours": 12
  },
  "stages": [
    { "id": "egg",      "hatchSeconds": 60 },
    { "id": "blob",     "afterHatch": true, "mattersForEvolution": false },
    { "id": "juvenile", "reachDays": 1.0 },
    { "id": "adult",    "reachDays": 3.5, "branchSelect": true },
    { "id": "apex",     "minAwakeHours": 72, "gated": true }
  ],
  "lifespanDays": { "naturalMin": 18, "naturalMax": 24, "pausedDuringSleep": true },
  "branchSelection": {
    "order": ["neglectOverride", "dominantAxis", "fallback"],
    "neglectOverride": { "neglectGte": 70, "careMistakesGte": 8, "branch": "DISTANT" },
    "dominantAxis": {
      "minValue": 55,
      "minLeadOverSecond": 12,
      "map": { "vigor": "SWIFT", "nocturnality": "FERAL", "bond": "BONDED", "discipline": "STALWART" }
    },
    "fallback": "DRIFTER",
    "wildcardChance": 0.0
  },
  "apexGate": {
    "minCareMistakesMax": 2,
    "minWinRatio": 0.70,
    "minBattles": 15,
    "dominantAxisGte": 60,
    "distantParallelApex": { "ignoresWinRatio": true, "ignoresCareMistakes": true }
  },
  "traitedEgg": {
    "requireLivedPastLifespan": true,
    "requireStageAtLeast": "adult",
    "lifetimeCareMistakesMax": 4,
    "boonByStage": { "adult": 1, "apex": 2 },
    "boonCap": 6,
    "boonEffects": { "evoGateBonusPctPerPoint": 5, "startingAxisNudgeMaxPerPoint": 0.5 }
  }
}
```

---

## 9. Tuning notes for the developer

- **`lifespanDays` and the stage `reachDays` are the emotional-tempo dial.** Halve them for a
  fast, high-churn "build a local reputation quickly" feel; double them to make each creature
  precious. Decide this deliberately — it changes the whole game's pulse.
- **Legibility lever:** `maxDailyDelta` and `minLeadOverSecond` control how sharply behavior maps
  to outcome. Higher lead requirement = subtler, more mysterious; lower = players crack the rules
  faster. Start subtle.
- Keep `wildcardChance` at 0 until the deterministic mapping is verified end-to-end; only then
  consider a small value if outcomes feel too mechanical.
- Expose every value in this config through the optional `RemoteBackstop` remote-config seam so
  balance can be tuned later without an app update — but it must load from the **bundled local
  copy by default** and never require the server.
- Build a **debug overlay** (dev builds only) that shows the live axis values, current
  care-mistake count, and the branch the creature is currently trending toward, so you can verify
  the mapping without waiting real days. This overlay is the one place the hidden numbers are
  allowed to appear.
