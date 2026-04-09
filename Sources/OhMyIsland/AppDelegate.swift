import AppKit
import SwiftUI
import os.log

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.codeisland", category: "AppDelegate")

    var panelController: PanelWindowController?
    private var hookServer: HookServer?
    private var codexSessionWatcher: CodexSessionWatcher?
    private var hookRecoveryTimer: Timer?
    private var lastHookCheck: Date = .distantPast
    

    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("CodeIsland must stay running")
        ProcessInfo.processInfo.disableSuddenTermination()
        // Pre-set app icon so Dock/menu bar use the packaged bundle icon.
        NSApp.applicationIconImage = SettingsWindowController.bundleAppIcon()
        if ConfigInstaller.install() {
            Self.log.info("Hooks installed")
        } else {
            Self.log.warning("Failed to install hooks")
        }

        hookServer = HookServer(appState: appState)
        hookServer?.start()

        // Codex integration via FSEvents on ~/.codex/sessions/, avoiding the
        // "Running hook" TUI noise caused by registering Codex hooks.
        codexSessionWatcher = CodexSessionWatcher(appState: appState)
        codexSessionWatcher?.start()

        panelController = PanelWindowController(appState: appState)
        panelController?.showPanel()

        appState.startSessionDiscovery()
        BuddyService.shared.load()
        UsageTracker.shared.start()

        // Hooks auto-recovery: periodic + app activation trigger
        hookRecoveryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndRepairHooks()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.checkAndRepairHooks()
        }

        #if DEBUG
        // Preview mode: inject mock data if --preview flag is present
        if let scenario = DebugHarness.requestedScenario() {
            Self.log.debug("Loading scenario: \(scenario.rawValue)")
            DebugHarness.apply(scenario, to: appState)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                if appState.surface == .collapsed {
                    withAnimation(NotchAnimation.pop) {
                        appState.surface = .sessionList
                    }
                }
            }
            return
        }
        #endif

        // Check for updates silently after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            UpdateChecker.shared.checkForUpdates(silent: true)
        }

        playBootAnimation()
    }

    private func playBootAnimation() {
        SoundManager.shared.playBoot()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard appState.surface == .collapsed else { return }
            withAnimation(NotchAnimation.pop) {
                appState.surface = .sessionList
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if case .sessionList = appState.surface {
                withAnimation(NotchAnimation.close) {
                    appState.surface = .collapsed
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookRecoveryTimer?.invalidate()
        appState.saveSessions()
        hookServer?.stop()
        codexSessionWatcher?.stop()
        appState.stopSessionDiscovery()
        UsageTracker.shared.stop()
    }

    private func checkAndRepairHooks() {
        guard Date().timeIntervalSince(lastHookCheck) > 60 else { return }
        lastHookCheck = Date()
        let repaired = ConfigInstaller.verifyAndRepair()
        if !repaired.isEmpty {
            Self.log.info("Auto-repaired hooks for: \(repaired.joined(separator: ", "))")
        }
    }
}
