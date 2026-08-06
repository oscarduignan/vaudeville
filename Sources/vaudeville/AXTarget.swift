import AppKit
import ApplicationServices

/// A window belonging to another app, grabbed via the Accessibility API.
/// `frame` is in Cocoa screen coordinates (origin bottom-left of the primary screen).
struct GrabbedWindow {
    let element: AXUIElement
    let app: NSRunningApplication
    let frame: CGRect
}

enum AXTarget {
    static func isTrusted(promptIfNeeded: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: promptIfNeeded] as CFDictionary)
    }

    /// AX coordinates have their origin at the top-left of the primary screen, y down.
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func frontmostWindow() -> GrabbedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var win: AXUIElement?
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success {
            win = (ref as! AXUIElement)
        } else {
            ref = nil
            if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
               let list = ref as? [AXUIElement] {
                win = list.first
            }
        }
        guard let win, let axFrame = frame(of: win), axFrame.width > 1, axFrame.height > 1 else { return nil }

        let cocoa = CGRect(x: axFrame.minX,
                           y: primaryScreenHeight - axFrame.minY - axFrame.height,
                           width: axFrame.width,
                           height: axFrame.height)
        return GrabbedWindow(element: win, app: app, frame: cocoa)
    }

    /// Window frame in AX (top-left origin) coordinates.
    private static func frame(of win: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }
        var p = CGPoint.zero
        var s = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    /// Moves the window so its Cocoa-coordinate origin lands at `origin`.
    static func move(_ w: GrabbedWindow, toCocoaOrigin origin: CGPoint) {
        var p = CGPoint(x: origin.x, y: primaryScreenHeight - origin.y - w.frame.height)
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(w.element, kAXPositionAttribute as CFString, value)
    }
}
