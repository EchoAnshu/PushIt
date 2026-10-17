import ctypes
import os
import time

import cv2
import numpy as np

from config import Config
from form_analyzer import FormAnalyzer
from pose_detector import (
    LEFT_ELBOW,
    LEFT_SHOULDER,
    LEFT_WRIST,
    RIGHT_ELBOW,
    RIGHT_SHOULDER,
    RIGHT_WRIST,
    PoseDetector,
    body_alignment_deviation,
    posture_valid,
)
from pushup_counter import PushUpCounter, combine_angles, side_angle

PUSHUP_MSG = "Move into push-up position"
READY_MSG = "Ready"
VIEW_MSG = "Move fully into view"

TEXT_COLORS = {
    "good": (60, 220, 80),
    "warn": (30, 165, 255),
    "bad": (70, 70, 255),
    "info": (225, 225, 225),
}


def open_camera(config):
    for backend in (cv2.CAP_DSHOW, cv2.CAP_MSMF, cv2.CAP_ANY):
        capture = cv2.VideoCapture(config.CAMERA_INDEX, backend)
        if capture.isOpened():
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, config.FRAME_WIDTH)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, config.FRAME_HEIGHT)
            return capture
        capture.release()
    return None


def bring_to_front(window_name):
    if os.name != "nt":
        return
    try:
        user32 = ctypes.windll.user32
        hwnd = user32.FindWindowW(None, window_name)
        if not hwnd:
            return
        user32.ShowWindow(hwnd, 9)
        hwnd_topmost = -1
        hwnd_notopmost = -2
        flags = 0x0002 | 0x0001
        user32.SetWindowPos(hwnd, hwnd_topmost, 0, 0, 0, 0, flags)
        user32.SetWindowPos(hwnd, hwnd_notopmost, 0, 0, 0, 0, flags)
        user32.SetForegroundWindow(hwnd)
    except Exception:
        pass


def letterbox(frame, target_w, target_h):
    h, w = frame.shape[:2]
    if w == 0 or h == 0 or target_w <= 0 or target_h <= 0:
        return frame
    scale = min(target_w / w, target_h / h)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    resized = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_AREA)
    canvas = np.zeros((target_h, target_w, 3), dtype=np.uint8)
    x = (target_w - new_w) // 2
    y = (target_h - new_h) // 2
    canvas[y : y + new_h, x : x + new_w] = resized
    return canvas


def draw_text_with_bg(frame, text, center_x, baseline_y, scale, color, pad=8):
    (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, scale, 2)
    x0 = max(pad, min(center_x - tw // 2, frame.shape[1] - tw - pad))
    top = baseline_y - th
    overlay = frame.copy()
    cv2.rectangle(overlay, (x0 - pad, top - pad), (x0 + tw + pad, baseline_y + pad), (20, 20, 20), -1)
    cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)
    cv2.putText(frame, text, (x0, baseline_y), cv2.FONT_HERSHEY_SIMPLEX, scale, color, 2, cv2.LINE_AA)


def feedback_color(feedback):
    if feedback == "Good Rep":
        return TEXT_COLORS["good"]
    if feedback == "Incomplete Rep":
        return TEXT_COLORS["bad"]
    if feedback in (READY_MSG, "Step into view"):
        return TEXT_COLORS["info"]
    return TEXT_COLORS["warn"]


def draw_panel(frame, rows):
    max_width = 0
    for text, _, scale in rows:
        (tw, _), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, scale, 2)
        max_width = max(max_width, tw)
    width = 24 + max_width
    height = 22 + 30 * len(rows)
    overlay = frame.copy()
    cv2.rectangle(overlay, (10, 10), (10 + width, 10 + height), (20, 20, 20), -1)
    cv2.addWeighted(overlay, 0.55, frame, 0.45, 0, frame)
    for index, (text, color, scale) in enumerate(rows):
        cv2.putText(
            frame,
            text,
            (24, 40 + index * 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            scale,
            color,
            2,
            cv2.LINE_AA,
        )


def format_angles(left, right, angle):
    def value(side):
        return f"{side:>3.0f}" if side is not None else " --"

    avg = f"{angle:4.1f}" if angle is not None else " --"
    return f"Elbow L {value(left)}  R {value(right)}  avg {avg}"


def build_rows(counter, analyzer, left, right, angle, fps):
    state_color = (0, 255, 0) if counter.state == PushUpCounter.UP else (0, 0, 255)
    if counter.state == PushUpCounter.UNKNOWN:
        state_color = (0, 215, 255)
    return [
        (f"REPS: {counter.count}", (255, 255, 255), 1.15),
        (f"Good {analyzer.good_reps}  Bad {analyzer.incorrect_reps}  Inc {counter.incomplete_reps}", (210, 210, 210), 0.6),
        (f"State: {counter.state}", state_color, 0.75),
        (format_angles(left, right, angle), (255, 255, 255), 0.65),
        (f"FPS {fps:4.1f}", (190, 190, 190), 0.55),
        ("q quit | r reset", (170, 170, 170), 0.5),
    ]


def main():
    config = Config
    capture = open_camera(config)
    if capture is None:
        print("ERROR: Could not open the webcam. Check the connection and that no other app is using it.")
        return 1

    try:
        detector = PoseDetector(config)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        capture.release()
        return 1
    counter = PushUpCounter(config)
    analyzer = FormAnalyzer(config)
    previous_time = time.time()
    fps = 0.0
    rep_flash_until = 0.0
    lost_frames = 0
    posture_invalid_frames = 0
    was_tracked = False
    fullscreen = False
    window_ready = False

    print("AI Push-Up Counter is running.")
    print("Get into the push-up position in front of the camera.")
    print("Press 'q' or ESC to quit, 'r' to reset, 'f' to toggle fullscreen.")
    cv2.namedWindow(config.WINDOW_NAME, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(config.WINDOW_NAME, config.FRAME_WIDTH, config.FRAME_HEIGHT)

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                print("ERROR: Failed to read a frame from the webcam.")
                break

            if config.MIRROR:
                frame = cv2.flip(frame, 1)

            height, width = frame.shape[:2]
            detector.process(frame)
            landmarks = detector.landmarks

            angle = None
            left = None
            right = None
            deviation = None
            posture_raw = True
            if landmarks is not None:
                left = side_angle(landmarks, LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, width, height)
                right = side_angle(landmarks, RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST, width, height)
                angle = combine_angles(left, right, config.MIN_VISIBILITY)
                posture_raw = posture_valid(
                    landmarks,
                    width,
                    height,
                    config.MIN_VISIBILITY,
                    config.POSTURE_WRIST_OVERHEAD_FRACTION,
                    config.PUSHUP_MIN_HAND_DEPTH_FRACTION,
                    config.PUSHUP_MAX_TORSO_VERTICALITY,
                )
                deviation = body_alignment_deviation(
                    landmarks,
                    width,
                    height,
                    config.MIN_VISIBILITY,
                )
                detector.draw_landmarks(frame, landmarks)

            if posture_raw:
                posture_invalid_frames = 0
            else:
                posture_invalid_frames += 1
            posture_ok = posture_invalid_frames < config.POSTURE_INVALID_GRACE_FRAMES

            tracked = angle is not None and posture_ok
            lost_frames = 0 if angle is not None else lost_frames + 1

            if not posture_ok:
                analyzer.feedback = PUSHUP_MSG
            elif lost_frames > config.LANDMARK_LOST_FEEDBACK_FRAMES:
                analyzer.feedback = VIEW_MSG
            elif tracked and not was_tracked:
                analyzer.feedback = READY_MSG
            was_tracked = tracked

            state = counter.update(angle, visible=angle is not None, posture_ok=posture_ok)
            analyzer.update(
                counter.smoothed_angle,
                state,
                counter.rep_completed,
                counter.incomplete_event,
                deviation,
            )

            now = time.time()
            if counter.rep_completed:
                rep_flash_until = now + 0.45
            delta = now - previous_time
            previous_time = now
            if delta > 0:
                fps = 0.9 * fps + 0.1 * (1.0 / delta)

            draw_panel(frame, build_rows(counter, analyzer, left[0] if left else None, right[0] if right else None, angle, fps))

            draw_text_with_bg(
                frame,
                analyzer.feedback,
                width // 2,
                height - 18,
                0.9,
                feedback_color(analyzer.feedback),
            )

            if now < rep_flash_until:
                draw_text_with_bg(frame, "REP!", width // 2, 110, 1.6, TEXT_COLORS["good"], pad=14)

            display = frame
            if fullscreen:
                win_w = int(cv2.getWindowProperty(config.WINDOW_NAME, cv2.WND_PROP_WIDTH))
                win_h = int(cv2.getWindowProperty(config.WINDOW_NAME, cv2.WND_PROP_HEIGHT))
                if win_w > 0 and win_h > 0:
                    display = letterbox(frame, win_w, win_h)
            cv2.imshow(config.WINDOW_NAME, display)
            if not window_ready:
                bring_to_front(config.WINDOW_NAME)
                window_ready = True

            key = cv2.waitKey(1) & 0xFF
            if key in config.QUIT_KEYS:
                break
            if key == config.RESET_KEY:
                counter.reset()
                analyzer.reset()
                was_tracked = False
            if key == config.FULLSCREEN_KEY:
                fullscreen = not fullscreen
                if fullscreen:
                    user32 = ctypes.windll.user32
                    screen_w = user32.GetSystemMetrics(0)
                    screen_h = user32.GetSystemMetrics(1)
                    cv2.namedWindow(config.WINDOW_NAME, cv2.WINDOW_NORMAL)
                    cv2.resizeWindow(config.WINDOW_NAME, screen_w, screen_h)
                else:
                    cv2.resizeWindow(config.WINDOW_NAME, config.FRAME_WIDTH, config.FRAME_HEIGHT)
    except KeyboardInterrupt:
        pass
    finally:
        capture.release()
        detector.close()
        cv2.destroyAllWindows()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())