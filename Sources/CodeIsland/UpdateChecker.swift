import AppKit
import os.log

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()
    private static let log = Logger(subsystem: "com.codeisland", category: "UpdateChecker")
    private let repo = "wxtsky/CodeIsland"

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(silent: Bool = true) {
        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self, let data, error == nil else {
                Self.log.debug("Update check failed: \(error?.localizedDescription ?? "no data")")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else { return }

            let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let local = self.currentVersion

            if self.isNewer(remote: remote, local: local) {
                DispatchQueue.main.async {
                    self.showUpdateAlert(remoteVersion: remote, releaseURL: htmlURL)
                }
            } else if !silent {
                DispatchQueue.main.async {
                    self.showUpToDateAlert()
                }
            }
        }.resume()
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    private func showUpdateAlert(remoteVersion: String, releaseURL: String) {
        // Ensure we have a proper activation policy for showing the alert
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.regular)
        }

        let alert = NSAlert()
        alert.messageText = L10n.shared["update_available_title"]
        alert.informativeText = String(format: L10n.shared["update_available_body"], remoteVersion, currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.shared["download_update"])
        alert.addButton(withTitle: L10n.shared["later"])

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        // Restore previous policy
        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.accessory)
        }

        if response == .alertFirstButtonReturn {
            if let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showUpToDateAlert() {
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.regular)
        }

        let alert = NSAlert()
        alert.messageText = L10n.shared["no_update_title"]
        alert.informativeText = String(format: L10n.shared["no_update_body"], currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.shared["ok"])

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()

        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
