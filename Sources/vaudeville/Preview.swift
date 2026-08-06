import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Renders the hook and curtain artwork to PNGs without touching the screen —
/// for iterating on the props between performances.
enum Preview {
    static func run(dir: String) -> Int32 {
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("vaudeville: cannot create \(dir): \(error.localizedDescription)\n".utf8))
            return 1
        }

        let curtainImage = Curtain.renderImage(size: CGSize(width: 1512, height: 982), scale: 1)
        writePNG(curtainImage, to: dir + "/curtain.png")

        if let hookImage = renderHook(width: 1000, height: 520) {
            writePNG(hookImage, to: dir + "/hook.png")
        }
        return 0
    }

    private static func renderHook(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Dim stage backdrop so the brass reads properly.
        ctx.setFillColor(CGColor(red: 0.12, green: 0.09, blue: 0.15, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        ctx.translateBy(x: CGFloat(width) - 320, y: CGFloat(height) / 2)
        Hook.draw(in: ctx, radius: 80)
        return ctx.makeImage()
    }

    static func writePNG(_ image: CGImage, to path: String) {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
