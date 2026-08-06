import AppKit
import CoreGraphics

/// The app icon, rendered by the app itself: the velvet drop with the hook
/// reaching in from the wings. Written as a 1024px PNG that the packaging
/// script turns into an .icns.
enum Icon {
    static func render(size: Int = 1024) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let s = CGFloat(size)

        // Big Sur-style rounded plate with a transparent margin around it.
        let plate = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.055, dy: s * 0.055)
        let shape = CGPath(roundedRect: plate, cornerWidth: s * 0.19, cornerHeight: s * 0.19, transform: nil)
        ctx.addPath(shape)
        ctx.clip()

        let curtain = Curtain.renderImage(size: plate.size, scale: 1)
        ctx.draw(curtain, in: plate)

        ctx.saveGState()
        ctx.translateBy(x: s * 0.40, y: s * 0.52)
        Hook.draw(in: ctx, radius: s * 0.155)
        ctx.restoreGState()

        // Soft rim so the plate edge reads against light backgrounds.
        ctx.addPath(shape)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
        ctx.setLineWidth(s * 0.008)
        ctx.strokePath()

        return ctx.makeImage()
    }
}
