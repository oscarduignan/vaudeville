import AppKit

/// The classic brass stage hook. Local coordinate origin is the center of the
/// crook's mouth — position the layer where the victim's edge should be caught.
/// The pole runs off toward `side`, far past the screen edge.
final class Hook {
    enum Side { case left, right }

    let layer = CALayer()
    let radius: CGFloat

    private static let dark = NSColor(red: 0.20, green: 0.13, blue: 0.03, alpha: 1)
    private static let brass = NSColor(red: 0.66, green: 0.49, blue: 0.16, alpha: 1)
    private static let shine = NSColor(red: 0.93, green: 0.83, blue: 0.55, alpha: 1)

    init(side: Side, crookRadius: CGFloat) {
        radius = crookRadius
        let dir: CGFloat = side == .right ? 1 : -1
        let path = Hook.path(dir: dir, radius: crookRadius, poleLength: 6000)

        func stroke(_ width: CGFloat, _ color: NSColor, dy: CGFloat = 0) -> CAShapeLayer {
            let s = CAShapeLayer()
            s.path = path
            s.fillColor = nil
            s.strokeColor = color.cgColor
            s.lineWidth = width
            s.lineCap = .round
            s.lineJoin = .round
            if dy != 0 { s.setAffineTransform(CGAffineTransform(translationX: 0, y: dy)) }
            return s
        }

        let outline = stroke(radius * 0.34 + 7, Hook.dark)
        outline.shadowColor = NSColor.black.cgColor
        outline.shadowOpacity = 0.45
        outline.shadowRadius = 10
        outline.shadowOffset = CGSize(width: 0, height: -8)
        let body = stroke(radius * 0.34, Hook.brass)
        let gleam = stroke(max(3, radius * 0.09), Hook.shine, dy: radius * 0.07)

        layer.addSublayer(outline)
        layer.addSublayer(body)
        layer.addSublayer(gleam)

        // Turned brass knob on the tip of the crook.
        let tipAngle = CGFloat(322.0 * .pi / 180.0)
        let tip = CGPoint(x: dir * crookRadius * cos(tipAngle), y: crookRadius * sin(tipAngle))
        let ballR = radius * 0.24 + 3
        let ball = CAShapeLayer()
        ball.path = CGPath(ellipseIn: CGRect(x: tip.x - ballR, y: tip.y - ballR,
                                             width: ballR * 2, height: ballR * 2), transform: nil)
        ball.fillColor = Hook.brass.cgColor
        ball.strokeColor = Hook.dark.cgColor
        ball.lineWidth = 4
        layer.addSublayer(ball)
    }

    /// Draws the hook with plain CG strokes (previews and the app icon), mouth
    /// centered on the current origin, pole running off toward +x.
    static func draw(in ctx: CGContext, radius: CGFloat) {
        let path = Hook.path(dir: 1, radius: radius, poleLength: 6000)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        func stroke(_ lineWidth: CGFloat, _ color: NSColor, dy: CGFloat = 0) {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: dy)
            ctx.addPath(path)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(color.cgColor)
            ctx.strokePath()
            ctx.restoreGState()
        }
        stroke(radius * 0.34 + 7, Hook.dark)
        stroke(radius * 0.34, Hook.brass)
        stroke(max(3, radius * 0.09), Hook.shine, dy: radius * 0.07)

        let tipAngle = CGFloat(322.0 * .pi / 180.0)
        let tip = CGPoint(x: radius * cos(tipAngle), y: radius * sin(tipAngle))
        let ballR = radius * 0.24 + 3
        let ballRect = CGRect(x: tip.x - ballR, y: tip.y - ballR, width: ballR * 2, height: ballR * 2)
        ctx.setFillColor(Hook.brass.cgColor)
        ctx.fillEllipse(in: ballRect)
        ctx.setStrokeColor(Hook.dark.cgColor)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: ballRect)
    }

    /// Pole along y = +radius, then the crook sweeps from the top of the mouth
    /// (90°) around through the bottom (270°) to a tip curling back up at 322°,
    /// leaving the mouth open toward the pole side — ready to catch a neck.
    static func path(dir: CGFloat, radius r: CGFloat, poleLength: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: dir * poleLength, y: r))
        p.addLine(to: CGPoint(x: 0, y: r))
        var deg: CGFloat = 90
        while deg <= 322 {
            let a = deg * .pi / 180
            p.addLine(to: CGPoint(x: dir * r * cos(a), y: r * sin(a)))
            deg += 3
        }
        return p
    }
}
