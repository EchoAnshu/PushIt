import numpy as np

from config import Config


def calculate_angle(point_a, point_b, point_c):
    a = np.asarray(point_a, dtype=float)
    b = np.asarray(point_b, dtype=float)
    c = np.asarray(point_c, dtype=float)

    ba = a - b
    bc = c - b
    denominator = np.linalg.norm(ba) * np.linalg.norm(bc)
    if denominator == 0.0:
        return 0.0

    cosine = np.dot(ba, bc) / denominator
    cosine = np.clip(cosine, -1.0, 1.0)
    return float(np.degrees(np.arccos(cosine)))


def side_angle(landmarks, shoulder_index, elbow_index, wrist_index, width, height):
    shoulder = landmarks[shoulder_index]
    elbow = landmarks[elbow_index]
    wrist = landmarks[wrist_index]

    visibility = min(shoulder.visibility, elbow.visibility, wrist.visibility)
    angle = calculate_angle(
        (shoulder.x * width, shoulder.y * height),
        (elbow.x * width, elbow.y * height),
        (wrist.x * width, wrist.y * height),
    )
    return angle, visibility


def combine_angles(left, right, min_visibility):
    candidates = [angle for angle, visibility in (left, right) if visibility >= min_visibility]
    if not candidates:
        return None
    return float(sum(candidates) / len(candidates))


class PushUpCounter:
    UP = "UP"
    DOWN = "DOWN"
    UNKNOWN = "UNKNOWN"

    def __init__(self, config=Config):
        self.config = config
        self.reset()

    def reset(self):
        self.state = self.UNKNOWN
        self.count = 0
        self.rep_completed = False
        self.incomplete_reps = 0
        self.incomplete_event = False
        self.smoothed_angle = None
        self.min_angle = None
        self.max_angle = None
        self.lost_frames = 0
        self._attempt_drop = False

    def _reset_cycle(self):
        self.state = self.UNKNOWN
        self.smoothed_angle = None
        self.min_angle = None
        self.max_angle = None
        self._attempt_drop = False

    def _handle_loss(self):
        self.lost_frames += 1
        if self.lost_frames > self.config.LANDMARK_LOST_GRACE_FRAMES:
            self.lost_frames = 0
            self._reset_cycle()
        return self.state

    def _smooth(self, angle):
        if self.smoothed_angle is None:
            self.smoothed_angle = angle
        else:
            alpha = self.config.ANGLE_SMOOTHING
            self.smoothed_angle = alpha * angle + (1.0 - alpha) * self.smoothed_angle
        return self.smoothed_angle

    def update(self, elbow_angle, visible=True, posture_ok=True):
        self.rep_completed = False
        self.incomplete_event = False

        if not posture_ok:
            self.lost_frames = 0
            self._reset_cycle()
            return self.state

        if not visible or elbow_angle is None:
            return self._handle_loss()

        self.lost_frames = 0
        angle = self._smooth(elbow_angle)
        self.min_angle = angle if self.min_angle is None else min(self.min_angle, angle)
        self.max_angle = angle if self.max_angle is None else max(self.max_angle, angle)

        if angle >= self.config.ELBOW_UP_ANGLE:
            was_down = self.state == self.DOWN
            self.state = self.UP
            if was_down:
                self.count += 1
                self.rep_completed = True
            if self._attempt_drop:
                self.incomplete_reps += 1
                self.incomplete_event = True
                self._attempt_drop = False
        elif angle <= self.config.ELBOW_DOWN_ANGLE:
            self._attempt_drop = False
            self.state = self.DOWN
        elif self.state == self.UP:
            if angle < self.config.ELBOW_UP_ANGLE - self.config.INCOMPLETE_DROP_FROM_UP:
                self._attempt_drop = True

        return self.state
