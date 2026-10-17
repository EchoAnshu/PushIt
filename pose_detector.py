import contextlib
import math
import os
import shutil
import time
import urllib.request

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

from config import Config

MODEL_URLS = {
    "lite": "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task",
    "full": "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task",
    "heavy": "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task",
}

NOSE = 0
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28

POSE_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10),
    (11, 12),
    (11, 13), (13, 15),
    (15, 17), (15, 19), (15, 21),
    (17, 19),
    (12, 14), (14, 16),
    (16, 18), (16, 20), (16, 22),
    (18, 20),
    (11, 23), (12, 24), (23, 24),
    (23, 25), (24, 26), (25, 27), (26, 28),
    (27, 29), (28, 30), (29, 31), (30, 32),
    (27, 31), (28, 32),
]

KEY_LANDMARKS = (
    LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_ELBOW, RIGHT_ELBOW,
    LEFT_WRIST, RIGHT_WRIST,
    LEFT_HIP, RIGHT_HIP,
    LEFT_KNEE, RIGHT_KNEE,
    LEFT_ANKLE, RIGHT_ANKLE,
)

ARM_LANDMARKS = (
    LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_ELBOW, RIGHT_ELBOW,
    LEFT_WRIST, RIGHT_WRIST,
)


def _midpoint(landmarks, indices, min_visibility):
    if any(landmarks[index].visibility < min_visibility for index in indices):
        return None
    return (
        sum(landmarks[index].x for index in indices) / 2.0,
        sum(landmarks[index].y for index in indices) / 2.0,
    )


def posture_valid(
    landmarks,
    width,
    height,
    min_visibility,
    max_above_ratio,
    min_hand_depth,
    max_torso_verticality,
):
    sides = (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
    )
    for shoulder_index, elbow_index, wrist_index in sides:
        shoulder = landmarks[shoulder_index]
        elbow = landmarks[elbow_index]
        wrist = landmarks[wrist_index]
        if min(shoulder.visibility, elbow.visibility, wrist.visibility) < min_visibility:
            continue
        shoulder_y = shoulder.y * height
        elbow_x = elbow.x * width
        elbow_y = elbow.y * height
        wrist_y = wrist.y * height
        upper_arm = math.hypot(elbow_x - shoulder.x * width, elbow_y - shoulder_y)
        if upper_arm <= 0.0:
            continue
        wrist_rise = -(wrist_y - shoulder_y) / upper_arm
        if wrist_rise > max_above_ratio:
            return False

    shoulder = _midpoint(landmarks, (LEFT_SHOULDER, RIGHT_SHOULDER), min_visibility)
    hip = _midpoint(landmarks, (LEFT_HIP, RIGHT_HIP), min_visibility)
    if shoulder is None or hip is None:
        return True
    shoulder_x = shoulder[0] * width
    shoulder_y = shoulder[1] * height
    hip_x = hip[0] * width
    hip_y = hip[1] * height
    torso = math.hypot(hip_x - shoulder_x, hip_y - shoulder_y)
    if torso <= 0.0:
        return True

    if shoulder_y < hip_y and (hip_y - shoulder_y) / torso > max_torso_verticality:
        return False

    for shoulder_index, elbow_index, wrist_index in sides:
        shoulder = landmarks[shoulder_index]
        elbow = landmarks[elbow_index]
        wrist = landmarks[wrist_index]
        if min(shoulder.visibility, elbow.visibility, wrist.visibility) < min_visibility:
            continue
        hand_depth = (wrist.y * height - hip_y) / torso
        if hand_depth < min_hand_depth:
            return False
    return True


def body_alignment_deviation(landmarks, width, height, min_visibility):
    indices = (
        LEFT_SHOULDER, RIGHT_SHOULDER,
        LEFT_HIP, RIGHT_HIP,
        LEFT_ANKLE, RIGHT_ANKLE,
    )
    if any(landmarks[index].visibility < min_visibility for index in indices):
        return None

    shoulder_x = (landmarks[LEFT_SHOULDER].x + landmarks[RIGHT_SHOULDER].x) / 2.0
    shoulder_y = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2.0
    hip_x = (landmarks[LEFT_HIP].x + landmarks[RIGHT_HIP].x) / 2.0
    hip_y = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2.0
    ankle_x = (landmarks[LEFT_ANKLE].x + landmarks[RIGHT_ANKLE].x) / 2.0
    ankle_y = (landmarks[LEFT_ANKLE].y + landmarks[RIGHT_ANKLE].y) / 2.0

    hip_x *= width
    hip_y *= height

    line_x = ankle_x * width - shoulder_x * width
    line_y = ankle_y * height - shoulder_y * height
    side_x = hip_x - shoulder_x * width
    side_y = hip_y - shoulder_y * height

    length_sq = line_x * line_x + line_y * line_y
    if length_sq <= 0.0:
        return None
    perpendicular = abs(line_x * side_y - line_y * side_x)
    return perpendicular / length_sq


@contextlib.contextmanager
def quiet_native_logs():
    try:
        devnull_fd = os.open(os.devnull, os.O_WRONLY)
    except OSError:
        yield
        return
    saved_fd = None
    try:
        saved_fd = os.dup(2)
        os.dup2(devnull_fd, 2)
        yield
    finally:
        if saved_fd is not None:
            os.dup2(saved_fd, 2)
            os.close(saved_fd)
        os.close(devnull_fd)


def ensure_model(model_path, model_url, timeout=30):
    if os.path.isfile(model_path) and os.path.getsize(model_path) > 0:
        return model_path
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    tmp_path = model_path + ".part"
    try:
        with urllib.request.urlopen(model_url, timeout=timeout) as response, open(tmp_path, "wb") as out_file:
            shutil.copyfileobj(response, out_file)
        if os.path.getsize(tmp_path) == 0:
            raise RuntimeError("downloaded model file is empty")
        os.replace(tmp_path, model_path)
    except Exception:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        raise
    return model_path


class PoseDetector:
    def __init__(self, config=Config):
        self.config = config
        variant = config.POSE_MODEL_VARIANT
        if variant not in MODEL_URLS:
            raise ValueError(f"Unknown POSE_MODEL_VARIANT: {variant}")
        model_path = os.path.join(config.MODEL_DIR, f"pose_landmarker_{variant}.task")
        try:
            ensure_model(model_path, MODEL_URLS[variant])
        except Exception as exc:
            raise RuntimeError(
                f"Could not download the '{variant}' pose model. Check your internet "
                f"connection, or place the model file at '{model_path}'. ({exc})"
            ) from exc

        base_options = mp_python.BaseOptions(model_asset_path=model_path)
        options = vision.PoseLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=config.MIN_DETECTION_CONFIDENCE,
            min_pose_presence_confidence=config.MIN_TRACKING_CONFIDENCE,
            min_tracking_confidence=config.MIN_TRACKING_CONFIDENCE,
            output_segmentation_masks=False,
        )
        with quiet_native_logs():
            self.landmarker = vision.PoseLandmarker.create_from_options(options)
        self.result = None
        self._last_timestamp_ms = -1

    def process(self, frame_bgr):
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        rgb = np.ascontiguousarray(rgb)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        timestamp_ms = self._next_timestamp()
        with quiet_native_logs():
            self.result = self.landmarker.detect_for_video(mp_image, timestamp_ms)
        return self.result

    def _next_timestamp(self):
        timestamp_ms = int(time.monotonic() * 1000)
        if timestamp_ms <= self._last_timestamp_ms:
            timestamp_ms = self._last_timestamp_ms + 1
        self._last_timestamp_ms = timestamp_ms
        return timestamp_ms

    @property
    def landmarks(self):
        if self.result is None or not self.result.pose_landmarks:
            return None
        return self.result.pose_landmarks[0]

    def draw_landmarks(self, frame, landmarks):
        height, width = frame.shape[:2]
        min_visibility = self.config.MIN_VISIBILITY
        points = [
            (int(lm.x * width), int(lm.y * height))
            for lm in landmarks
        ]
        for start, end in POSE_CONNECTIONS:
            if landmarks[start].visibility < min_visibility or landmarks[end].visibility < min_visibility:
                continue
            cv2.line(frame, points[start], points[end], (0, 200, 0), 2)
        for index in KEY_LANDMARKS:
            landmark = landmarks[index]
            color = (0, 165, 255) if index in ARM_LANDMARKS else (255, 0, 0)
            if landmark.visibility < min_visibility:
                color = (0, 0, 255)
            cv2.circle(frame, points[index], 5, color, -1)
        return frame

    def close(self):
        self.landmarker.close()
