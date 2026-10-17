# AI Push-Up Counter --- Technical Project Plan

## 1. Objective

Create a webcam-based application that detects body pose, identifies
push-up movements, counts valid repetitions, and provides basic form
feedback.

## 2. Technology Selection

### Python

Main programming language for computer vision, numerical processing, and
AI-related functionality.

### MediaPipe

Used for human pose detection and body landmarks.

### OpenCV

Used for webcam capture and image/video processing.

### NumPy

Used for mathematical calculations such as distances and joint angles.

### Flask

Connects the Python processing layer to a web interface.

### Database

SQLite is sufficient for a basic project. MySQL can be used if required
by the course.

## 3. Processing Pipeline

``` text
Camera Frame
     ↓
OpenCV Capture
     ↓
MediaPipe Pose Detection
     ↓
Extract Landmarks
     ↓
Calculate Joint Angles
     ↓
Determine Body Position
     ↓
Push-Up State Machine
     ↓
Validate Repetition
     ↓
Update Counter
     ↓
Generate Form Feedback
```

## 4. Push-Up State Machine

### UP

Arms are relatively extended.

### DOWN

The user lowers the body and the elbow angle decreases.

### REP COMPLETED

The user returns from DOWN to UP.

``` text
UP → DOWN → UP = 1 REP
```

This prevents repeated counting while the user remains in one position.

## 5. Angle Calculation

For three points A, B and C, where B is the joint:

``` text
        A
       /
      B
               C
```

Calculate vectors:

``` text
BA = A - B
BC = C - B
```

Then calculate the angle:

``` text
angle = arccos((BA · BC) / (|BA| × |BC|))
```

The elbow angle can be one of the main signals for push-up detection.

## 6. Form Analysis

### Depth

If the elbow angle does not become sufficiently small during the
downward phase:

``` text
Feedback: "Go Lower"
```

### Body Alignment

Compare shoulder, hip, and ankle positions to estimate whether the body
is reasonably straight.

``` text
Feedback: "Keep Your Back Straight"
```

### Rep Validation

Only accept a repetition after the complete sequence:

``` text
UP → DOWN → UP
```

## 7. Accuracy Considerations

The system should account for camera angle, lighting, body visibility,
clothing, multiple people, partial body visibility, and different body
proportions.

For the college version, instruct the user to position the camera so the
body is clearly visible from a suitable angle.

## 8. Development Phases

### Phase 1 --- Webcam

-   Open webcam
-   Display live video
-   Verify camera permissions

### Phase 2 --- Pose Detection

-   Install MediaPipe
-   Detect pose landmarks
-   Draw skeleton landmarks

### Phase 3 --- Angle Calculation

-   Extract shoulder, elbow and wrist landmarks
-   Calculate elbow angle
-   Display the angle

### Phase 4 --- Rep Counter

Implement:

``` text
UP → DOWN → UP
```

and count completed repetitions.

### Phase 5 --- Form Analysis

Add rules for insufficient depth, poor body alignment, and incomplete
repetitions.

### Phase 6 --- Web Interface

Create Start Workout, Stop Workout, Live Counter, Timer, Form Score, and
Workout Summary.

### Phase 7 --- Database

Optionally store:

``` text
User
Date
Duration
Total Reps
Good Reps
Bad Reps
Form Score
```

## 9. Minimum Viable Product

The first working version only needs:

-   Webcam
-   MediaPipe
-   OpenCV
-   Elbow-angle calculation
-   Push-up state machine
-   Live repetition counter

Everything else should be added after the counter works reliably.

## 10. Final Demonstration

1.  Open the application.
2.  Allow webcam access.
3.  Position the camera correctly.
4.  Start the workout.
5.  Perform several push-ups.
6.  Show the live counter.
7.  Demonstrate an intentionally incomplete push-up.
8.  Show form feedback.
9.  Stop the workout.
10. Display the final workout summary.
