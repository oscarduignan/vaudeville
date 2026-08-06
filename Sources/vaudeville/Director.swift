import AppKit

/// One beat of the performance: `update` receives progress 0...1.
struct Phase {
    let name: String
    let duration: Double
    var onStart: (() -> Void)? = nil
    var update: ((Double) -> Void)? = nil
}

/// Runs phases back to back on a 120 Hz timer, wrapping each tick in a
/// CATransaction with implicit animations disabled so layer positions track
/// the timeline exactly (and stay in lockstep with the AX window moves).
final class Director {
    private let phases: [Phase]
    private let completion: () -> Void
    private var timer: Timer?
    private var index = -1
    private var phaseStart: CFTimeInterval = 0

    init(phases: [Phase], completion: @escaping () -> Void) {
        self.phases = phases
        self.completion = completion
    }

    func start() {
        guard !phases.isEmpty else { completion(); return }
        advance()
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func advance() {
        index += 1
        guard index < phases.count else {
            timer?.invalidate()
            timer = nil
            completion()
            return
        }
        phaseStart = CACurrentMediaTime()
        phases[index].onStart?()
    }

    private func tick() {
        guard index < phases.count else { return }
        let phase = phases[index]
        let elapsed = CACurrentMediaTime() - phaseStart
        let p = phase.duration <= 0 ? 1 : min(elapsed / phase.duration, 1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        phase.update?(p)
        CATransaction.commit()

        if p >= 1 { advance() }
    }
}
