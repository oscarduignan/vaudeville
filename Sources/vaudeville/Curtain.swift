import AppKit
import CoreGraphics

/// Procedurally rendered heavy velvet drop curtain: sinusoidal folds, a gold
/// braid band, and hanging fringe along the hem. No image assets involved.
enum Curtain {
    static func makeLayer(size: CGSize, scale: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.contents = renderImage(size: size, scale: scale)
        layer.contentsGravity = .resize
        layer.frame = CGRect(origin: .zero, size: size)
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: -14)
        return layer
    }

    static func intermissionLayer(text: String, width: CGFloat, y: CGFloat, scale: CGFloat) -> CATextLayer {
        let gold = NSColor(red: 0.93, green: 0.79, blue: 0.45, alpha: 1)
        let font = NSFont(name: "Didot", size: 46) ?? NSFont.systemFont(ofSize: 46, weight: .medium)
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: gold,
            .kern: 10,
        ])
        let l = CATextLayer()
        l.string = attr
        l.alignmentMode = .center
        l.frame = CGRect(x: 0, y: y, width: width, height: 90)
        l.contentsScale = scale
        l.opacity = 0
        l.shadowColor = NSColor.black.cgColor
        l.shadowOpacity = 0.8
        l.shadowRadius = 5
        l.shadowOffset = CGSize(width: 0, height: -3)
        return l
    }

    static func renderImage(size: CGSize, scale: CGFloat) -> CGImage {
        let w = max(1, Int(size.width * scale))
        let h = max(1, Int(size.height * scale))
        let s = Double(scale)

        let velvetShadow = (r: 40.0, g: 4.0, b: 11.0)
        let velvetHigh = (r: 178.0, g: 36.0, b: 55.0)
        let goldLo = (r: 122.0, g: 86.0, b: 20.0)
        let goldHi = (r: 238.0, g: 198.0, b: 96.0)

        // Per-column fold shading: a primary fold wave, phase-wobbled by a
        // slower wave so the pleats look sewn, not machine-perfect.
        let foldW = 105.0 * s
        var fold = [Double](repeating: 0, count: w)
        for x in 0..<w {
            let fx = Double(x)
            let wave = sin(fx / foldW * 2 * .pi + 1.15 * sin(fx / (foldW * 3.3)))
            fold[x] = pow(0.5 + 0.5 * wave, 1.3)
        }

        let fringeLen = Int(46 * s)
        let braidTop = fringeLen + Int(24 * s)
        let strandPeriod = max(2, Int(7 * s))
        let strandWidth = max(1, Int(4 * s))

        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        for row in 0..<h {
            let yFromBottom = h - 1 - row
            // Lit from the proscenium above: brightest up top, dim at the floor.
            let vertical = 0.72 + 0.28 * (1 - Double(row) / Double(h))
            for x in 0..<w {
                let i = (row * w + x) * 4
                let f = fold[x]
                var c: (r: Double, g: Double, b: Double)

                if yFromBottom < braidTop {
                    let strand = x % strandPeriod < strandWidth
                    let strandLen = fringeLen - Int(6.0 * s * (0.5 + 0.5 * sin(Double(x) * 0.13 / s)))
                    if yFromBottom >= fringeLen {
                        // Braid band, shimmering with the folds.
                        c = mix(goldLo, goldHi, 0.35 + 0.65 * f)
                    } else if strand && yFromBottom < strandLen {
                        // Hanging tassel strands, darker toward their tips.
                        let droop = Double(yFromBottom) / Double(max(1, strandLen))
                        c = mix(goldLo, goldHi, f * (0.45 + 0.55 * droop))
                    } else {
                        // Gaps between strands read as deep hem shadow.
                        c = mix(velvetShadow, velvetHigh, f * 0.25)
                    }
                } else {
                    c = mix(velvetShadow, velvetHigh, f)
                }

                pixels[i] = UInt8(min(255, c.r * vertical))
                pixels[i + 1] = UInt8(min(255, c.g * vertical))
                pixels[i + 2] = UInt8(min(255, c.b * vertical))
                pixels[i + 3] = 255
            }
        }

        return pixels.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h,
                                bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return ctx.makeImage()!
        }
    }

    private static func mix(_ a: (r: Double, g: Double, b: Double),
                            _ b: (r: Double, g: Double, b: Double),
                            _ t: Double) -> (r: Double, g: Double, b: Double) {
        let t = Ease.clamp01(t)
        return (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }
}
