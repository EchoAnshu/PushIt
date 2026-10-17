from config import Config
from pushup_counter import PushUpCounter


class FormAnalyzer:
    def __init__(self, config=Config):
        self.config = config
        self.reset()

    def reset(self):
        self.feedback = "Step into view"
        self.good_reps = 0
        self.incorrect_reps = 0
        self.last_min_angle = None
        self.last_max_deviation = None
        self._cycle_min_angle = None
        self._cycle_max_deviation = 0.0
        self._prev_state = None
        self._cycle_open = False

    def _open_cycle(self):
        self._cycle_min_angle = None
        self._cycle_max_deviation = 0.0
        self._cycle_open = True

    def update(self, angle, state, rep_completed, incomplete_event, deviation):
        if state == PushUpCounter.UNKNOWN:
            self._cycle_open = False
            self._cycle_min_angle = None
            self._cycle_max_deviation = 0.0
        elif state == PushUpCounter.DOWN and self._prev_state != PushUpCounter.DOWN:
            self._open_cycle()
        self._prev_state = state

        if self._cycle_open:
            if angle is not None:
                self._cycle_min_angle = (
                    angle if self._cycle_min_angle is None else min(self._cycle_min_angle, angle)
                )
            if deviation is not None:
                self._cycle_max_deviation = max(self._cycle_max_deviation, deviation)

        if rep_completed:
            self._finalize_rep()
        elif incomplete_event:
            self.feedback = "Incomplete Rep"

        return self.feedback

    def _finalize_rep(self):
        self._cycle_open = False
        min_angle = self._cycle_min_angle
        max_deviation = self._cycle_max_deviation
        self.last_min_angle = min_angle
        self.last_max_deviation = max_deviation

        depth_ok = min_angle is not None and min_angle <= self.config.GOOD_DEPTH_ANGLE
        alignment_ok = max_deviation <= self.config.ALIGNMENT_MAX_DEVIATION

        if depth_ok and alignment_ok:
            self.good_reps += 1
            self.feedback = "Good Rep"
            return

        self.incorrect_reps += 1
        if not depth_ok and not alignment_ok:
            self.feedback = "Go Lower  -  Keep Your Back Straight"
        elif not depth_ok:
            self.feedback = "Go Lower"
        else:
            self.feedback = "Keep Your Back Straight"