import AppKit

/// GitHub Releases を見て、新しい DMG があればアプリ自身を入れ替える軽量アップデータ。
@MainActor
final class Updater: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let repo = "mimifuwacc/adderall"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// アップデート確認。`silent` のときは「最新です」のダイアログを出さない（起動時の自動チェック用）。
    func check(silent: Bool) {
        guard status != .checking, status != .downloading else { return }
        status = .checking
        Task { await performCheck(silent: silent) }
    }

    private func performCheck(silent: Bool) async {
        do {
            let release = try await fetchLatestRelease()
            let latest = normalize(release.tag_name)
            guard let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
                  let url = URL(string: asset.browser_download_url) else {
                status = .failed("リリースに DMG が見つかりませんでした")
                return
            }

            if isNewer(latest, than: normalize(currentVersion)) {
                status = .available(version: latest)
                promptInstall(version: latest, url: url)
            } else {
                status = .upToDate
                if !silent { showInfo("最新です", "Adderall \(currentVersion) は最新バージョンです。") }
            }
        } catch {
            status = .failed(error.localizedDescription)
            if !silent { showInfo("確認に失敗しました", error.localizedDescription) }
        }
    }

    // MARK: - GitHub API

    private struct GHRelease: Decodable {
        let tag_name: String
        let assets: [GHAsset]
    }
    private struct GHAsset: Decodable {
        let name: String
        let browser_download_url: String
    }

    private func fetchLatestRelease() async throws -> GHRelease {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Adderall", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "Updater", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "GitHub API への接続に失敗しました"])
        }
        return try JSONDecoder().decode(GHRelease.self, from: data)
    }

    // MARK: - バージョン比較

    private func normalize(_ v: String) -> String {
        v.hasPrefix("v") ? String(v.dropFirst()) : v
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    // MARK: - インストール

    private func promptInstall(version: String, url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "新しいバージョンがあります"
        alert.informativeText = "Adderall \(version) が利用可能です（現在 \(currentVersion)）。\n今すぐアップデートしますか？"
        alert.addButton(withTitle: "今すぐアップデート")
        alert.addButton(withTitle: "後で")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            status = .idle
            return
        }
        status = .downloading
        Task { await downloadAndInstall(url: url) }
    }

    private func downloadAndInstall(url: URL) async {
        do {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            let dmg = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Adderall-update.dmg")
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: tmp, to: dmg)
            try installFromDMG(dmg)
            // installFromDMG が成功すると入れ替えスクリプトを起動してアプリを終了する。
        } catch {
            status = .failed(error.localizedDescription)
            showInfo("アップデートに失敗しました", error.localizedDescription)
        }
    }

    private func installFromDMG(_ dmg: URL) throws {
        let mount = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("adderall-mnt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)

        // DMG をマウント。
        guard Shell.run("/usr/bin/hdiutil",
                        ["attach", "-nobrowse", "-mountpoint", mount.path, dmg.path]).status == 0 else {
            throw NSError(domain: "Updater", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "DMG のマウントに失敗しました"])
        }

        let newApp = mount.appendingPathComponent("Adderall.app").path
        let currentApp = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        // 自分が終了するのを待ってから入れ替え、quarantine を外して再起動する。
        let script = """
        #!/bin/bash
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.3; done
        /bin/rm -rf "\(currentApp)"
        /bin/cp -R "\(newApp)" "\(currentApp)"
        /usr/bin/xattr -dr com.apple.quarantine "\(currentApp)" 2>/dev/null
        /usr/bin/hdiutil detach "\(mount.path)" 2>/dev/null
        /bin/rm -f "\(dmg.path)"
        /usr/bin/open "\(currentApp)"
        """
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("adderall-update.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptURL.path]
        try task.run() // 待たない（デタッチ）。

        NSApp.terminate(nil)
    }

    // MARK: - 補助

    private func showInfo(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
