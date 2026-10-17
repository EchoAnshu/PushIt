# ARCHITECTURE

Push-Up Battle: two Android phones on the same Wi-Fi. Each phone validates its own
player's reps on-device; the host phone arbitrates the match and stores ratings.

## Data flow

```text
Phone camera (frames)
  -> ML Kit Pose Detection (on-device, 33 landmarks)
  -> Referee engine (angles, posture, state machine)     app/lib/engine
  -> REP events
  -> HTTP over LAN to host phone                         app/lib/net
  -> Host arbiter (tempo cap, score, winner, Elo)        app/lib/server
  -> SQLite: players, matches                            app/lib/storage
  -> Room state polled by both phones (GET /state)       app/lib/net
```

The Python MVP at the repo root (`main.py`, `pose_detector.py`, `pushup_counter.py`,
`form_analyzer.py`) is the reference implementation for the referee engine.

## Components

| Path | Responsibility |
|------|----------------|
| `app/lib/engine/` | Pure Dart referee: angle math, posture validation, UP/DOWN state machine |
| `app/lib/vision/` | Camera + ML Kit pose wrapper, calibration |
| `app/lib/server/` | Embedded shelf HTTP server + match arbiter (host only) |
| `app/lib/storage/` | sqflite wrapper: ratings, match log (host only) |
| `app/lib/net/` | Join / ready / rep / state client |
| `app/lib/ui/` | Screens: home, host, join, solo, match, result |

## LAN protocol (v1)

JSON over HTTP on the host phone's LAN IP. Clients poll `GET /state` every 300 ms.

| Method + path | Body / response |
|---------------|-----------------|
| `POST /join` | `{playerId, name}` -> `{ok, rating}` |
| `POST /ready` | `{playerId, ready}` -> `{ok}` |
| `POST /rep` | `{playerId, ts}` -> `{counted, reason}` |
| `GET /state` | -> `{phase, players: [{id, name, reps, ready, rating}], countdown, winner}` |
| `POST /start` | host only: begins countdown |
| `POST /reset` | host only: rematch |

`phase`: `lobby` -> `ready` -> `countdown` -> `live` -> `result`.

## Referee rules (ported from Python `config.py`)

| Rule | Value |
|------|-------|
| UP threshold (elbow angle >=) | 155 deg |
| DOWN threshold (elbow angle <=) | 100 deg |
| Angle smoothing alpha | 0.65 |
| Good depth (cycle min angle <=) | 90 deg |
| Max body alignment deviation | 0.18 |
| Incomplete rep: drop from UP | 20 deg |
| Wrist overhead rejection fraction | 0.2 |
| Minimum hand depth below hips | 0.35 |
| Max torso verticality (blocks standing curls) | 0.75 |
| Posture invalid grace | 5 frames |
| Landmark lost grace | 15 frames |
| Tempo cap (host-enforced) | 500 ms between reps |

## SQLite schema (host phone only)

```sql
CREATE TABLE players (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  rating INTEGER NOT NULL DEFAULT 1000
);

CREATE TABLE matches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  host_id TEXT NOT NULL,
  guest_id TEXT NOT NULL,
  winner_id TEXT NOT NULL,
  target INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

Nothing else is stored: no video, no frames, no personal data.

## Elo

```text
expected = 1 / (1 + 10^((Rb - Ra) / 400))
delta    = round(K * (score - expected)),  K = 32
rating   = max(100, rating + delta)
```
