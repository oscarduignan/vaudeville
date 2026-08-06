import AVFoundation
import Foundation

/// Pit orchestra of one: synthesizes the slide whistle, the curtain whoosh,
/// and the landing thud straight into PCM buffers — no sound files.
final class Orchestra {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private(set) var ready = false

    init(enabled: Bool) {
        guard enabled else { return }
        for _ in 0..<3 {
            let p = AVAudioPlayerNode()
            players.append(p)
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = 0.55
        do {
            try engine.start()
            for p in players { p.play() }
            ready = true
        } catch {
            FileHandle.standardError.write(Data("vaudeville: sound unavailable (\(error.localizedDescription))\n".utf8))
        }
    }

    func playWhistle(duration: Double) { play(whistle(f0: 1350, f1: 250, duration: duration)) }
    func playWhoosh(duration: Double) { play(whoosh(duration: duration)) }
    func playThud() { play(thud()) }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard ready, let buffer else { return }
        players[nextPlayer].scheduleBuffer(buffer)
        nextPlayer = (nextPlayer + 1) % players.count
    }

    private func makeBuffer(duration: Double) -> (AVAudioPCMBuffer, UnsafeMutablePointer<Float>, Int)? {
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        return (buf, buf.floatChannelData![0], Int(frames))
    }

    /// Descending gliss with a touch of second harmonic for the reedy tone.
    private func whistle(f0: Double, f1: Double, duration d: Double) -> AVAudioPCMBuffer? {
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let sr = format.sampleRate
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            let f = f0 * pow(f1 / f0, t / d)
            phase += 2 * .pi * f / sr
            let env = min(t / 0.015, 1) * Ease.clamp01((d - t) / 0.08)
            data[i] = Float((sin(phase) + 0.35 * sin(2 * phase)) * 0.30 * env)
        }
        return buf
    }

    /// Low-passed noise sweeping darker as the fabric accelerates.
    private func whoosh(duration d: Double) -> AVAudioPCMBuffer? {
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng: UInt64 = 0x9E37_79B9_7F4A_7C15
        var lp = 0.0
        for i in 0..<n {
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let white = Double(Int64(bitPattern: rng)) / Double(Int64.max)
            let u = Double(i) / Double(n)
            lp += (0.30 * (1 - u) + 0.02) * (white - lp)
            data[i] = Float(lp * pow(sin(.pi * u), 1.6) * 1.1)
        }
        return buf
    }

    /// 80-ish Hz body with a short noise knock: velvet meeting the stage.
    private func thud() -> AVAudioPCMBuffer? {
        let d = 0.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let sr = format.sampleRate
        var rng: UInt64 = 0xDEAD_BEEF_CAFE_F00D
        var lp = 0.0
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let white = Double(Int64(bitPattern: rng)) / Double(Int64.max)
            lp += 0.12 * (white - lp)
            phase += 2 * .pi * (82 * (1 - 0.35 * t)) / sr
            data[i] = Float(sin(phase) * exp(-7 * t) * 0.85 + lp * exp(-28 * t) * 0.5)
        }
        return buf
    }
}
