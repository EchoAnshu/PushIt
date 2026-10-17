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
- [x] Solo screen: rep count, good/incomplete feedback
- [x] Undistorted cover-fit preview (FittedBox), portrait lock, no FPS clutter
- [x] Ting sound on every counted rep (`assets/sounds/ting.wav`, audioplayers)
- [x] Setup/calibration screen: 4 holds (side top/bottom, front top/bottom), saved via shared_preferences
- [x] Front-facing counting: nose-to-hands drop metric normalized by shoulder width, auto-switches with side view
- [x] `flutter analyze` clean, 22 tests green, debug APK builds
- [ ] Verify on a physical Android phone (counts reps in side AND front view)
- [ ] Update this file, commit, push

Note: builds on this OneDrive path need Windows long-path support
(`HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1`, admin) -
otherwise Gradle fails deleting deep paths with "Unable to delete directory".

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
