# Kindred — Battle Resolution Spec

> **Audience: the engine and the developer.** Feed this to Claude Code alongside the main prompt
> and the evolution-mapping spec. This defines how an interactive, skill-driven battle stays
> deterministic and cheat-resistant over a proximity-only (BLE) link with no server. Every number
> is a **tunable default**.

---

## 1. Design goals

- **Stats matter, but skill can overcome a gap.** A well-played underdog should be able to beat a
  carelessly-played stronger creature, and even a *moderately* stronger one — but not an
  overwhelmingly stronger one. Skill has a **defined ceiling** (Section 5) so battles never become
  either pure stat-checks or pure twitch contests.
- **Interactive, short, readable.** A battle runs ~15–25 seconds, expressed in clean vector UI.
- **Deterministic & verifiable** given the inputs, so two phones independently agree on the result
  and neither can lie about it (Section 6).
- **"Smart mashing," not fastest fingers.** The skill is timing + stamina pacing, not raw taps per
  second — fairer, more accessible, and naturally rate-bounded for anti-cheat.

---

## 2. How this refines the "deterministic seeded resolver" from the main prompt

The main prompt says battles are deterministic from stats + a shared seed. With live input that
becomes: **deterministic given `(signedCreatureA, signedCreatureB, seed, inputStreamA,
inputStreamB)`.** Both devices exchange inputs in lockstep and run the *same* simulation, so they
reach the *same* result independently. Stats can't be faked (the creature state is signed at
pairing), and inputs can't be faked usefully (they're rate-bounded and both sides validate). This
*replaces* the "pure stats+seed" phrasing — same determinism, now input-driven.

---

## 3. Stat block (derived from the evolution spec)

Each creature carries a 5-stat block, each `1–100`, derived at evolution time from its branch bias
+ trait axes + lineage boon. Persist it on the `Creature`; don't recompute mid-battle.

| Stat | Drives | Fed mainly by |
|---|---|---|
| `hp` | total health pool | Discipline, Stalwart bias |
| `attack` | base damage | Vigor, Feral bias |
| `defense` | damage mitigation | Distant / Stalwart bias |
| `speed` | strike order + timing-window width | Vigor, Swift bias |
| `stamina` | mash budget before fatigue | Vigor, Bond bias |

**Per-branch bias** (multipliers applied to a neutral 50 baseline, then nudged by the actual axis
values and `+boon`):

| Branch | hp | attack | defense | speed | stamina |
|---|---|---|---|---|---|
| `SWIFT`    | 0.85 | 1.05 | 0.90 | 1.30 | 1.05 |
| `FERAL`    | 0.95 | 1.30 | 0.85 | 1.10 | 0.95 |
| `BONDED`   | 1.05 | 1.00 | 1.00 | 1.00 | 1.20 |
| `STALWART` | 1.30 | 0.95 | 1.25 | 0.80 | 1.00 |
| `DISTANT`  | 1.00 | 0.95 | 1.35 | 0.90 | 0.95 |
| `DRIFTER`  | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |

Clamp final stats to `1–100`. `apex` forms get a flat bump (default +8 to two signature stats).

---

## 4. Battle structure

- A battle is a fixed **5 exchanges** (bounded length → deterministic, schoolyard-friendly).
- Each creature starts at full `hp` (scaled to a battle HP pool, e.g. `hp × 4`).
- Each exchange: **both creatures act**, ordered by `speed` (faster strikes first; a strike that
  drops the opponent to 0 ends the battle immediately — speed has real value).
- After 5 exchanges (or an earlier KO), the winner is whoever has HP left, or the higher **HP %**
  if both survive. Exact ties break toward the higher `speed`, then the battle seed.

### The interactive layer (per exchange, ~2.5 s window)

Each exchange opens a short input window with **two blended skill inputs**:

1. **Timing** — a marker sweeps a bar; tapping when it crosses the **sweet spot** yields a clean
   hit. `timingQuality` ∈ [0,1] by how centered the tap was. The sweet-spot **width scales with
   `speed`** (faster creatures make good timing easier — the stat amplifies skill).
2. **Mash** — extra taps in the window build a power burst, but **each tap spends stamina**, and
   the mash bonus **scales with remaining stamina**, so spamming fades fast. The skill is *pacing*
   bursts across the 5 exchanges, not tapping as fast as possible.

The **defender** also gets a single timing input to **guard** (reduce incoming damage), so defense
is interactive too, not passive.

**Accessibility:** provide a low-dexterity mode (hold-and-release for timing, an auto-mash assist
that converts a single hold into a stamina-paced burst). Because skill is timing+pacing rather than
APM, this mode stays competitive — keep it that way.

---

## 5. Damage formula (where the skill ceiling lives)

Per exchange, for the acting attacker:

```
mashBonus   = (effMash / maxMash) * mashWeight * (curStamina / maxStamina)
timingBonus = timingQuality * timingWeight
skillBonus  = clamp(mashBonus + timingBonus, 0, SKILL_CAP_OFFENSE)   // e.g. 0..0.40

effAttack   = attack * (1 + skillBonus)

guardBonus  = clamp(defenderTimingQuality * guardWeight, 0, SKILL_CAP_DEFENSE)  // 0..0.30
effDefense  = defense * (1 + guardBonus)

damage      = max(1, round( (effAttack * ATK_K) / (effDefense + DEF_C) * HP_SCALE ))
```

**Why this gives the feel you want:** offense skill can lift effective attack by up to **+40%** and
defense skill can cut incoming damage by up to **~30%**. So a player can swing a battle by roughly
a **40% effective-stat band** through skill alone. Inside that band, *the better-played creature
wins regardless of stats* — exactly your "a better button masher beats a higher stat." Outside it
(a creature ~1.5×+ stronger, played competently), **stats win** and skill only narrows the margin.
`SKILL_CAP_OFFENSE` is the master dial for "how much can skill overcome stats."

Default: **no random crits** (keeps it legible and fully deterministic). An optional small
seeded crit chance can be enabled later via config if battles feel too flat.

---

## 6. Determinism, netcode & anti-cheat (lockstep, BLE, no server)

1. **Handshake (NFC tap → BLE):** each device sends its **signed** creature state (stat block,
   lineage, HMAC from Secure Enclave / Keystore) and a contribution to a **shared battle seed**
   (seed = hash(seedA ‖ seedB)). Reject if a signature fails.
2. **Per exchange, lockstep:** each device computes its own player's input **summary** for the
   window — `{ tapCount, timingOffsetMs, guardOffsetMs }` — and exchanges it with the peer. Both
   devices now hold *both* input summaries.
3. **Both run the identical deterministic resolver** on `(stats, seed, inputA, inputB)` for that
   exchange, producing the same HP deltas.
4. **State-hash check:** after each exchange both devices hash the resulting battle state and
   compare. **Any mismatch voids the battle** (no result recorded) — so tampering with stats or
   inputs mid-fight gains nothing; it just nullifies.
5. **Input plausibility bounds:** `tapCount` is clamped to `maxMash` (physically possible taps in
   the window); timing/guard offsets must fall within the window. Out-of-bounds inputs are clamped
   or void the battle. This is the same boundary philosophy as the evolution integrity layer.

For the prototype (mock transport, one device), simulate the peer's input stream locally with a
tunable "AI" input quality so the full resolver path — input summaries, lockstep, hashing — runs
end-to-end and is ready for real BLE later.

---

## 7. Outcome — what each creature carries away

- **Record:** win/loss updates the local head-to-head with that tamer and the `Roster` leaderboard.
- **Imprint (the "carries away" nudge):** small, bounded. Winner gains a tiny `confidence` nudge
  (e.g. +0.5 toward its dominant axis, capped per day); loser gains a tiny different mark (e.g. a
  tilt toward `defense`/`distant`). Keep these small so battles flavor a creature over time without
  letting a grinder min-max — and so the creature stays a portrait of *life*, not just of battling.
- No XP economy, no currency. Bragging rights and the leaderboard are the reward.

---

## 8. Machine-readable config (engine loads this)

```json
{
  "version": 1,
  "structure": { "exchanges": 5, "windowMs": 2500, "hpPoolMultiplier": 4, "orderBy": "speed" },
  "statBranchBias": {
    "SWIFT":    { "hp": 0.85, "attack": 1.05, "defense": 0.90, "speed": 1.30, "stamina": 1.05 },
    "FERAL":    { "hp": 0.95, "attack": 1.30, "defense": 0.85, "speed": 1.10, "stamina": 0.95 },
    "BONDED":   { "hp": 1.05, "attack": 1.00, "defense": 1.00, "speed": 1.00, "stamina": 1.20 },
    "STALWART": { "hp": 1.30, "attack": 0.95, "defense": 1.25, "speed": 0.80, "stamina": 1.00 },
    "DISTANT":  { "hp": 1.00, "attack": 0.95, "defense": 1.35, "speed": 0.90, "stamina": 0.95 },
    "DRIFTER":  { "hp": 1.00, "attack": 1.00, "defense": 1.00, "speed": 1.00, "stamina": 1.00 }
  },
  "apexStatBump": 8,
  "skill": {
    "SKILL_CAP_OFFENSE": 0.40,
    "SKILL_CAP_DEFENSE": 0.30,
    "mashWeight": 0.20,
    "timingWeight": 0.20,
    "guardWeight": 0.30,
    "maxMash": 12,
    "staminaPerTap": 1,
    "staminaRegenPerExchange": 3,
    "sweetSpotBaseMs": 250,
    "sweetSpotPerSpeedMs": 4
  },
  "damage": { "ATK_K": 6.0, "DEF_C": 12.0, "HP_SCALE": 1.0, "minDamage": 1 },
  "crit": { "enabled": false, "chance": 0.0, "multiplier": 1.5 },
  "netcode": {
    "lockstep": true,
    "shareSignedState": true,
    "perExchangeStateHashCheck": true,
    "voidOnMismatch": true
  },
  "outcome": {
    "winnerAxisNudge": 0.5,
    "loserDefenseNudge": 0.5,
    "dailyImprintCap": 2.0
  }
}
```

---

## 9. Build staging (prototype-minimum → full)

- **Prototype-minimum:** mash-only input + a single timing tap per exchange, deterministic resolver,
  per-exchange hash check against a locally-simulated opponent, win/loss to the Roster. No guard,
  no crits, no accessibility mode yet — but the lockstep/hashing path must be real so BLE drops in
  cleanly later.
- **Full:** add interactive guard, accessibility mode, apex bumps, imprint nudges, optional crits.

---

## 10. Tuning notes

- **`SKILL_CAP_OFFENSE` is the soul of battle feel.** Raise it and skill overwhelms stats (more
  "anyone can win"); lower it and stats dominate (raising your creature matters more). 0.40 is a
  deliberate middle — a well-played creature can overcome ~a 40% stat deficit. Tune by playtest.
- Keep **`crit.enabled` false** until the deterministic path is verified; randomness complicates
  the cross-device hash agreement and the "legible" feel.
- Expose this whole config through the `RemoteBackstop` remote-config seam (bundled local copy is
  the default; server never required), so battle balance can change without an app update.
- Add the dev-only debug overlay here too: show each side's `skillBonus`, stamina, and per-exchange
  damage so you can verify the stats-vs-skill curve without two phones.
