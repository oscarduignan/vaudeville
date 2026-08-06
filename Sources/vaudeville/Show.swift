import AppKit

/// Transparent, click-through stage that floats above everything (menu bar
/// and Dock included) on the target screen.
private final class StageWindow: NSWindow {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
}

final class TheShow {
    struct Config {
        var silent = false
        var curtainsOnly = false
        var restore = true
        var text = "INTERMISSION"
    }

    private let config: Config
    private let orchestra: Orchestra
    private var overlay: StageWindow!
    private var hook: Hook?
    private var curtain: CALayer!
    private var intermission: CATextLayer?
    private var director: Director!
    private var target: GrabbedWindow?
    private var targetHomeOrigin: CGPoint?

    init(config: Config) {
        self.config = config
        orchestra = Orchestra(enabled: !config.silent)
    }

    func begin(on screen: NSScreen, target: GrabbedWindow?) {
        self.target = target
        let sf = screen.frame
        let W = sf.width
        let H = sf.height

        overlay = StageWindow(frame: sf)
        let content = overlay.contentView!
        content.wantsLayer = true
        let root = content.layer!

        curtain = Curtain.makeLayer(size: sf.size, scale: screen.backingScaleFactor)
        let curtainRestY = H / 2
        let curtainDrop = H + 60   // parked fully above the top edge, shadow included
        curtain.position = CGPoint(x: W / 2, y: curtainRestY + curtainDrop)
        root.addSublayer(curtain)
        if !config.text.isEmpty {
            let text = Curtain.intermissionLayer(text: config.text, width: W,
                                                 y: H * 0.52, scale: screen.backingScaleFactor)
            curtain.addSublayer(text)
            intermission = text
        }

        var phases: [Phase] = []
        var restoreInfo: (window: GrabbedWindow, home: CGPoint, exitDX: CGFloat)?

        if let t = target {
            // Everything below works in the overlay's local (screen) coordinates.
            let win = t.frame.offsetBy(dx: -sf.minX, dy: -sf.minY)
            let fromRight = win.midX >= W / 2
            let dir: CGFloat = fromRight ? 1 : -1

            let radius = min(max(win.height * 0.16, 46), 90)
            let hook = Hook(side: fromRight ? .right : .left, crookRadius: radius)
            root.addSublayer(hook.layer)
            self.hook = hook

            // The crook's mouth catches the window just inside its offstage edge.
            let mouthX = fromRight ? win.maxX - radius * 0.5 : win.minX + radius * 0.5
            let mouthY = min(max(win.midY, radius + 24), H - radius - 24)
            let enterX = fromRight ? W + 2 * radius + 60 : -(2 * radius + 60)
            hook.layer.position = CGPoint(x: enterX, y: mouthY)

            // How far the pair must travel for the window to clear the stage.
            let exitDX: CGFloat = fromRight ? (W + 60) - win.minX : -(win.maxX + 60)
            let home = t.frame.origin
            targetHomeOrigin = home
            restoreInfo = (t, home, exitDX)
            var lastAXMove: CFTimeInterval = 0

            phases.append(Phase(name: "enter", duration: 0.55, update: { p in
                hook.layer.position.x = enterX + (mouthX - enterX) * Ease.outCubic(p)
            }))
            phases.append(Phase(name: "settle", duration: 0.4, update: { p in
                // A menacing little waggle while it takes aim.
                hook.layer.position.x = mouthX + 6 * sin(p * .pi * 4) * (1 - p)
            }))
            phases.append(Phase(name: "yank", duration: 0.62,
                onStart: { [orchestra] in orchestra.playWhistle(duration: 0.58) },
                update: { p in
                    let off = exitDX * Ease.inBack(p)
                    hook.layer.position.x = mouthX + off
                    // During the wind-up the hook eases backward; the window
                    // only moves once it is genuinely being dragged offstage.
                    let drag = dir > 0 ? max(0, off) : min(0, off)
                    let now = CACurrentMediaTime()
                    if now - lastAXMove > 1.0 / 60 || p >= 1 {
                        lastAXMove = now
                        AXTarget.move(t, toCocoaOrigin: CGPoint(x: home.x + drag, y: home.y))
                    }
                }))
            phases.append(Phase(name: "beat", duration: 0.2))
        } else if !config.curtainsOnly {
            // No window to grab: the hook gropes around the stage and leaves
            // empty-handed. The curtains fall to spare it further embarrassment.
            let hook = Hook(side: .right, crookRadius: 64)
            root.addSublayer(hook.layer)
            self.hook = hook
            let mouthX = W * 0.45
            let mouthY = H * 0.55
            let enterX = W + 190
            hook.layer.position = CGPoint(x: enterX, y: mouthY)

            phases.append(Phase(name: "enter", duration: 0.6, update: { p in
                hook.layer.position.x = enterX + (mouthX - enterX) * Ease.outCubic(p)
            }))
            phases.append(Phase(name: "grope", duration: 1.0, update: { p in
                hook.layer.position.x = mouthX + 34 * sin(p * .pi * 3)
                hook.layer.position.y = mouthY + 20 * sin(p * .pi * 5)
            }))
            phases.append(Phase(name: "retreat", duration: 0.5, update: { p in
                hook.layer.position.x = mouthX + (enterX - mouthX) * Ease.inCubic(p)
            }))
        }

        let dropDuration = 1.15
        phases.append(Phase(name: "drop", duration: dropDuration,
            onStart: { [orchestra, curtain] in
                orchestra.playWhoosh(duration: dropDuration * 0.62)
                // easeOutBounce first touches the floor at t = 1/2.75.
                DispatchQueue.main.asyncAfter(deadline: .now() + dropDuration / 2.75) {
                    orchestra.playThud()
                }
                _ = curtain // keep the capture list explicit for the update below
            },
            update: { [curtain] p in
                curtain!.position.y = curtainRestY + curtainDrop * (1 - Ease.outBounce(p))
            }))
        phases.append(Phase(name: "hold", duration: 2.6, update: { [weak self] p in
            guard let text = self?.intermission else { return }
            text.opacity = Float(min(Ease.clamp01(p / 0.18), Ease.clamp01((1 - p) / 0.18)))
        }))
        phases.append(Phase(name: "rise", duration: 1.35, update: { [curtain] p in
            curtain!.position.y = curtainRestY + curtainDrop * Ease.inCubic(p)
        }))

        if let info = restoreInfo, config.restore {
            var lastAXMove: CFTimeInterval = 0
            phases.append(Phase(name: "encore", duration: 0.55, update: { p in
                let now = CACurrentMediaTime()
                guard now - lastAXMove > 1.0 / 60 || p >= 1 else { return }
                lastAXMove = now
                let x = info.home.x + info.exitDX * (1 - Ease.outCubic(p))
                AXTarget.move(info.window, toCocoaOrigin: CGPoint(x: x, y: info.home.y))
            }))
        }

        director = Director(phases: phases) { [weak self] in
            self?.overlay.orderOut(nil)
            NSApp.terminate(nil)
        }
        overlay.orderFrontRegardless()
        director.start()
    }

    /// If the run is interrupted mid-show, put the victim back where it lived.
    func emergencyRestore() {
        guard let t = target, let home = targetHomeOrigin else { return }
        AXTarget.move(t, toCocoaOrigin: home)
    }
}
