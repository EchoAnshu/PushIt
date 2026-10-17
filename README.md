# AI Push-Up Counter & Form Analyzer

An AI-based fitness application that uses a webcam to detect body pose,
count push-ups automatically, and analyze basic exercise form.

## Tech Stack

-   **Python** --- main programming language
-   **MediaPipe Pose** --- human pose and body-landmark detection
-   **OpenCV** --- webcam/video capture and image processing
-   **NumPy** --- angle and numerical calculations
-   **Flask** --- web interface/API
-   **HTML, CSS, JavaScript** --- frontend
-   **SQLite/MySQL** --- optional workout-history database

## How It Works

``` text
Webcam
   ↓
OpenCV
   ↓
MediaPipe Pose
   ↓
Body Landmarks
   ↓
Joint-Angle Calculation
   ↓
Push-Up State Detection
   ↓
Rep Counter + Form Analysis
   ↓
Flask Web Interface
```

### Push-Up Detection

The system tracks landmarks around the shoulder, elbow, wrist, and hip.

A simplified state machine is:

``` text
UP → DOWN → UP = 1 REP
```

A repetition is counted only after a complete movement.

## Running the MVP (Phases 2-6)

### 1. Create a virtual environment and install dependencies

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Run the counter

```powershell
python main.py
```

On first run, the pose model is downloaded automatically into `models/`.

### 3. Controls

- `q` or `Esc` --- quit
- `r` --- reset the counter to zero

### Notes

- This build uses the current **MediaPipe Tasks API** (`PoseLandmarker`),
  because the legacy `mp.solutions` API was removed in MediaPipe 0.10.31.
  The Tasks API works with MediaPipe 0.10.9 through 1.x.
- MediaPipe ships Python-version-independent (`py3-none`) wheels, so this
  runs on Python 3.13.
- Position the camera so the whole body is visible from a front or side
  view. For a front view, hands must be planted below the hips so the
  counter can tell a real push-up from standing elbow bends.
- The counter only accepts a rep when (a) the wrist is not raised above
  the shoulder (blocks overhead arm raises) and (b) the hands are planted
  well below the hips (`PUSHUP_MIN_HAND_DEPTH_FRACTION`, default 0.35).
  This works from both front and side views and blocks standing curls and
  shoulder raises from being counted.
- Tune `ELBOW_UP_ANGLE`, `ELBOW_DOWN_ANGLE`, and `ANGLE_SMOOTHING` in
  `config.py` if your range of motion differs.
- Form feedback (Phase 7) is active: reps are labelled `Good Rep`,
  `Go Lower` (insufficient depth), `Keep Your Back Straight` (sagging or
  piked hips), or `Incomplete Rep` (a lowered-and-returned movement that
  never reached the DOWN threshold). The dashboard shows good/incorrect/
  incomplete counts.

## Planned Features

### Core

-   Live webcam feed
-   Human pose detection
-   Automatic push-up counting
-   Start/stop workout
-   Live repetition counter
-   Workout timer

### Form Analysis

-   `Go Lower`
-   `Keep Your Back Straight`
-   `Good Rep`
-   `Keep Your Elbows Controlled`

### Workout Summary

-   Total push-ups
-   Good repetitions
-   Incorrect repetitions
-   Form score
-   Workout duration
-   Average repetition tempo

### Optional

-   Workout history
-   Progress charts
-   User profiles
-   Multiple exercise modes

## Project Goal

Demonstrate computer vision, pose estimation, geometric analysis,
state-machine logic, web development, and optional database integration.

## Project Structure

``` text
pushup-ai/
├── app.py
├── pose_detector.py
├── pushup_counter.py
├── form_analyzer.py
├── requirements.txt
├── templates/
│   └── index.html
├── static/
│   ├── style.css
│   └── script.js
├── database/
│   └── database.py
└── README.md
```

## Future Scope

The same system can later support squats, sit-ups, lunges, planks,
exercise-specific form scoring, rep-tempo analysis, and personalized
workout recommendations.
