import Foundation

enum Ease {
    static func outCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    static func inCubic(_ t: Double) -> Double { t * t * t }

    /// Anticipation curve: dips negative first (the wind-up), then accelerates hard.
    static func inBack(_ t: Double) -> Double {
        let c = 1.70158
        return (c + 1) * t * t * t - c * t * t
    }

    /// Settles at 1 after a few decaying bounces — the heavy-object landing.
    static func outBounce(_ t: Double) -> Double {
        let n1 = 7.5625, d1 = 2.75
        var t = t
        if t < 1 / d1 { return n1 * t * t }
        if t < 2 / d1 { t -= 1.5 / d1; return n1 * t * t + 0.75 }
        if t < 2.5 / d1 { t -= 2.25 / d1; return n1 * t * t + 0.9375 }
        t -= 2.625 / d1
        return n1 * t * t + 0.984375
    }

    static func clamp01(_ t: Double) -> Double { min(1, max(0, t)) }
}
