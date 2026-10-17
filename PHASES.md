# PHASES

Push-Up Battle — phase tracker. This file is rechecked and updated after **every** phase, then committed and pushed.

## Decisions

- Flutter app, **Android only**.
- **LAN-only first**; online friend-code rooms deferred until Phases 1-5 are done.
- The host phone runs the match server (embedded HTTP server).
- Core mode: **Race to N** validated reps (Phase 4).
- Ratings persist in SQLite on the host phone. Only `players` and `matches` are stored.
  No video, no frames, no workout history.
- Referee is strict: sloppy reps do not count.

## Status

| # | Phase | Status | Exit criteria |
|---|-------|--------|---------------|
| 0 | Bootstrap: toolchain + repo + docs | done | repo visible on GitHub |
| 1 | Referee engine port to Dart + tests | done | all engine tests green |
| 2 | Camera + ML Kit pose + solo mode | in progress | counts reps on a real phone |
| 3 | LAN host + SQLite + QR join | pending | two phones in one room |
| 4 | Race-to-N battle + Elo | pending | full 1v1 match, ratings persist |
| 5 | Pace-survival / polish (optional) | pending | demo-ready |

## Phase checklists

### Phase 0 - Bootstrap
- [x] Install Flutter SDK, JDK 21, Android cmdline-tools (platform 36, build-tools 36)
- [x] `flutter doctor` Android toolchain green
- [x] `flutter create app --org com.pushit --project-name pushit_battle --platforms android`
- [x] Write PHASES.md, ARCHITECTURE.md, .gitignore
- [x] Push to https://github.com/EchoAnshu/PushIt

### Phase 1 - Referee engine (Dart port)
- [x] Port `calculate_angle`, `side_angle`, `combine_angles` -> `app/lib/engine/angles.dart`
- [x] Port `posture_valid` (wrist overhead, hand depth, torso verticality) -> `posture.dart`
- [x] Port `PushUpCounter` state machine -> `counter.dart`
- [x] Port `FormAnalyzer` -> `form_analyzer.dart`
- [x] Difficulty presets (lenient / standard / strict) + tempo cap setting
- [x] Unit tests incl. standing-curl rejection and plank acceptance (12 tests green)
- [x] Update this file, commit, push

### Phase 2 - Camera + solo mode
- [x] Camera frame stream + ML Kit pose detection (nv21 via legacy `camera_android` plugin; camerax can't stream ML Kit formats)
- [x] Solo screen: rep count, good/incomplete feedback, FPS
- [x] `flutter analyze` clean, 13 tests green, debug APK builds
- [ ] Calibration pass (deferred - standard preset thresholds for now)
- [ ] Verify on a physical Android phone (counts reps)
- [ ] Update this file, commit, push

### Phase 3 - LAN host + join
- [ ] Embedded shelf HTTP server (host phone)
- [ ] SQLite: players, matches tables
- [ ] Join flow: host shows QR, guest scans or enters code
- [ ] Room screen showing both players
- [ ] Update this file, commit, push

### Phase 4 - Race-to-N battle
- [ ] Ready check (both players in valid plank stance)
- [ ] 3-2-1 countdown, then match start
- [ ] Server-side arbitration: tempo cap, rep counting, winner
- [ ] Elo update and win/lose screen with rating delta
- [ ] Update this file, commit, push

### Phase 5 - Polish (optional)
- [ ] Pace-survival mode (strikes, elimination)
- [ ] Result summary screen
- [ ] Update this file, commit, push

## Workflow rule

After each phase: implement -> verify -> update this file -> `git commit` -> `git push origin main`.
