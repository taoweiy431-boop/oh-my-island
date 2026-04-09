import AppKit
import os.log

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case available(version: String, url: String)
    case failed(String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    private static let log = Logger(subsystem: "com.codeisland", category: "UpdateChecker")
    private let repo = "taoweiy431-boop/oh-my-island"

    @Published var status: UpdateStatus = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(silent: Bool = true) {
        if silent && currentVersion == "0.0.0" { return }

        status = .checking

        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            status = .failed("无效 URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    Self.log.debug("Update check failed: \(error.localizedDescription)")
                    self.status = .failed("网络错误")
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    self.status = .failed("解析失败")
                    return
                }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if self.isNewer(remote: remote, local: self.currentVersion) {
                    self.status = .available(version: remote, url: htmlURL)
                } else {
                    self.status = .upToDate(version: self.currentVersion)
                }
            }
        }.resume()
    }

    func openRelease() {
        if case .available(_, let urlString) = status, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
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
}
