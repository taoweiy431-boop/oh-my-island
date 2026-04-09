import AppKit
import SwiftUI

@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private var closeObserver: NSObjectProtocol?

    func show() {
        // Switch to regular activation policy so the window can receive focus
        NSApp.setActivationPolicy(.regular)
        // Use the actual bundle app icon so Dock matches the packaged asset catalog icon.
        NSApp.applicationIconImage = Self.bundleAppIcon()

        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenW = screen?.frame.width ?? 1440
        let screenH = screen?.frame.height ?? 900
        let winW = min(660, screenW * 0.5)
        let winH = min(540, screenH * 0.6)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .visible
        window.title = "Claude Island Settings"
        window.backgroundColor = NSColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1.0)
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: min(560, screenW * 0.4), height: min(420, screenH * 0.4))
        window.toolbar = nil
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Revert to accessory policy when settings window is closed
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            // Hide Dock tile first to avoid flash of default icon during transition
            NSApp.setActivationPolicy(.accessory)
            NSApp.hide(nil)
        }

        self.window = window
    }

    static func bundleAppIcon() -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        image.size = NSSize(width: 256, height: 256)
        return image
    }
}
