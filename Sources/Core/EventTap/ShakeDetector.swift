import Foundation
import CoreGraphics

/// Detects a natural, comfortable "shake" gesture during an active drag.
/// Because EventTapManager already verifies that a genuine file/content drag
/// session is active, these thresholds are tuned to feel effortless and responsive,
/// without requiring punishing arm speed or gigantic sweeps.
final class ShakeDetector {

    // MARK: - Configuration

    /// Distance (in points) the cursor must sweep and reverse from its peak.
    /// 75pt (~1.1 inches) is wide enough to avoid casual drift, but small enough
    /// to be a comfortable, natural wrist flick.
    private let turnThreshold: CGFloat = 75.0

    /// Minimum speed required (points/second).
    /// 1200 pt/s ensures the movement is active/intentional, but easily reachable
    /// with a normal wrist shake.
    private let minVelocity: CGFloat = 1200.0

    /// Maximum time allowed between consecutive turns (in seconds).
    /// 0.28s gives comfortable turnaround cadence.
    private let maxTurnInterval: TimeInterval = 0.28

    /// Maximum duration allowed for the entire shake gesture (in seconds).
    private let timeWindow: TimeInterval = 0.65

    /// Number of direction reversals required to trigger (3 reversals: e.g. Left -> Right -> Left -> Right).
    private let requiredReversals: Int = 3

    /// Cooldown between triggers to prevent duplicate spawns.
    private let cooldown: TimeInterval = 1.2

    // MARK: - State

    private var reversalTimestamps: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval = 0
    private var lastSampleTime: TimeInterval = 0

    // X-axis peak tracking
    private var xDirection: Int = 0 // +1 = moving right, -1 = moving left
    private var xPeak: CGFloat = 0

    // Y-axis peak tracking
    private var yDirection: Int = 0 // +1 = moving up, -1 = moving down
    private var yPeak: CGFloat = 0

    private var lastPoint: CGPoint?

    // MARK: - Public API

    /// Feed a new drag position. Returns `true` if a natural shake gesture is recognised.
    func processDragEvent(point: CGPoint) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime

        // Cooldown check
        if now - lastTriggerTime < cooldown {
            return false
        }

        guard let prev = lastPoint else {
            lastPoint = point
            lastSampleTime = now
            xPeak = point.x
            yPeak = point.y
            return false
        }

        let dt = now - lastSampleTime
        lastPoint = point
        lastSampleTime = now

        guard dt > 0.001 else { return false }

        // Calculate instantaneous velocity (points/second)
        let dist = hypot(point.x - prev.x, point.y - prev.y)
        let velocity = dist / CGFloat(dt)

        var turned = false

        // --- X Axis Peak Tracking ---
        let dx = point.x - prev.x
        if abs(dx) > 1.0 {
            if xDirection == 0 {
                xDirection = dx > 0 ? 1 : -1
                xPeak = point.x
            } else if xDirection == 1 { // Moving right
                if point.x > xPeak {
                    xPeak = point.x
                } else if xPeak - point.x >= turnThreshold {
                    // Reversed from right to left!
                    xDirection = -1
                    xPeak = point.x
                    turned = true
                }
            } else if xDirection == -1 { // Moving left
                if point.x < xPeak {
                    xPeak = point.x
                } else if point.x - xPeak >= turnThreshold {
                    // Reversed from left to right!
                    xDirection = 1
                    xPeak = point.x
                    turned = true
                }
            }
        }

        // --- Y Axis Peak Tracking ---
        let dy = point.y - prev.y
        if abs(dy) > 1.0 {
            if yDirection == 0 {
                yDirection = dy > 0 ? 1 : -1
                yPeak = point.y
            } else if yDirection == 1 { // Moving up
                if point.y > yPeak {
                    yPeak = point.y
                } else if yPeak - point.y >= turnThreshold {
                    yDirection = -1
                    yPeak = point.y
                    turned = true
                }
            } else if yDirection == -1 { // Moving down
                if point.y < yPeak {
                    yPeak = point.y
                } else if point.y - yPeak >= turnThreshold {
                    yDirection = 1
                    yPeak = point.y
                    turned = true
                }
            }
        }

        if turned {
            if velocity < minVelocity && reversalTimestamps.isEmpty {
                return false
            }

            // If the turnaround was too sluggish, reset
            if let lastTime = reversalTimestamps.last, now - lastTime > maxTurnInterval {
                reversalTimestamps.removeAll()
            }

            reversalTimestamps.append(now)
            NSLog("[ShakeDetector] 🔄 Reversal #%d detected (velocity: %.0f pt/s)", reversalTimestamps.count, velocity)
        }

        // Prune timestamps older than the sliding window
        reversalTimestamps.removeAll { now - $0 > timeWindow }

        if reversalTimestamps.count >= requiredReversals {
            NSLog("[ShakeDetector] 🎉 NATURAL SHAKE TRIGGERED! (%d reversals within %.2fs)", reversalTimestamps.count, timeWindow)
            lastTriggerTime = now
            reset()
            return true
        }

        return false
    }

    /// Resets all accumulated tracking state.
    func reset() {
        lastPoint = nil
        lastSampleTime = 0
        xDirection = 0
        yDirection = 0
        xPeak = 0
        yPeak = 0
        reversalTimestamps.removeAll()
    }
}
