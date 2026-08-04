# Changelog

## 0.4.2

- Enforce 100% function and line coverage for the deterministic engine in CI.
- Add focused coverage for frenzy, replay validation, input routing, ranking, settings, and effects.

## 0.4.1 - 2026-08-03

- Fix a 32-bit integer shift trap when constructing seeded simulations on WebAssembly.

## 0.4.0 - 2026-08-03

- Add versioned player progression with missions, levels, rewards, and cosmetic unlocks.
- Add per-mode run summaries and replay digests for trusted score submission.
- Expand accessible control settings with legacy-save migration.
- Add bounded input sensitivity and assist-mode difficulty scaling.
- Add configurable simulation difficulty without coupling rules to display size.
- Enforce strict Swift formatting and collect test coverage in CI.

## 0.3.0 - 2026-08-03

- Add paced wave scheduling to the authoritative simulation.
- Add Classic Raid, Moon Rush, Spirit Zen, Daily Haunt, and Boss Raid rules.
- Add target, armored, and cursed pumpkin roles.
- Add near-miss rewards, frenzy multipliers, last-chance events, and statistics.
- Add deterministic sweet pickup and inventory-recharge lifecycles.
- Add a semantic input router for digital, pointer, touch, remote, and controller hosts.
- Validate 100,000 generated wave windows in the expanded test suite.

## 0.2.0 - 2026-08-03

- Add a deterministic fixed-timestep `GameSimulation`.
- Add semantic move, direct-move, dash, shriek, and pause input actions.
- Add renderer-independent game events and normalized game state.
- Add versioned replay recording and stable quantized state digests.
- Add seeded wave composition and reaction-window safety validation.
- Make `GameSession` codable for replay and persistence infrastructure.
- Expand deterministic, bounds, replay, action, and wave tests.

## 0.1.1 - 2026-07-31

- Add shuffled seven-lane spawn distribution.

## 0.1.0 - 2026-07-31

- Initial reusable rules, spawning, combo, settings, and leaderboard package.
