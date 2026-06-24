import AppKit
import ServiceManagement

/// アプリの状態とシステム操作（pmset / caffeinate / sudoers / ログイン項目）をまとめて持つ。
final class AppModel: ObservableObject {
    @Published private(set) var sleepDisabled = false
    @Published private(set) var sudoersConfigured = false
    @Published private(set) var launchAtLogin = false

    /// ディスプレイのスリープも防ぐか（UserDefaults に永続化）。
    @Published var controlDisplaySleep: Bool {
        didSet {
            UserDefaults.standard.set(controlDisplaySleep, forKey: "controlDisplaySleep")
            syncDisplayCaffeinate()
        }
    }

    private var caffeinate: Process?

    init() {
        controlDisplaySleep = UserDefaults.standard.bool(forKey: "controlDisplaySleep")
        refresh()
    }

    // MARK: - 状態取得

    /// 全項目を更新（初回・設定画面を開いたとき）。sudo を1回叩く。
    func refresh() {
        refreshLive()
        sudoersConfigured = checkSudoers()
    }

    /// sudo を使わない軽い更新（5秒ごとのポーリング用）。
    func refreshLive() {
        sleepDisabled = readSleepDisabled()
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        syncDisplayCaffeinate()
    }

    /// `pmset -g` の SleepDisabled 行を読む（root 不要）。
    private func readSleepDisabled() -> Bool {
        guard let output = Shell.run("/usr/bin/pmset", ["-g"]).output else { return sleepDisabled }
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        return false
    }

    /// NOPASSWD 設定の有無だけを判定する。
    /// `-k` でキャッシュ済み sudo タイムスタンプを無視し、`-n` で実行前に拒否させるため、
    /// 「最近 sudo した」状態に惑わされず純粋に sudoers のルールだけを見られる。
    /// 現在値の再設定（no-op）なので状態は変わらない。
    private func checkSudoers() -> Bool {
        let arg = readSleepDisabled() ? "1" : "0"
        return Shell.run("/usr/bin/sudo", ["-k", "-n", "/usr/bin/pmset", "-a", "disablesleep", arg]).status == 0
    }

    // MARK: - トグル

    /// disablesleep を切り替える。成功すれば true。未設定などで失敗したら false。
    @discardableResult
    func toggle() -> Bool {
        setSleepDisabled(!sleepDisabled)
    }

    @discardableResult
    func setSleepDisabled(_ target: Bool) -> Bool {
        let arg = target ? "1" : "0"
        // sudoers で無パスワード許可済みの想定。-n でプロンプトを出さずに実行する。
        guard Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", arg]).status == 0 else {
            return false
        }
        sudoersConfigured = true // 通った=無パスワード許可あり
        refreshLive()
        return true
    }

    // MARK: - ディスプレイスリープ（caffeinate -d、root 不要・可逆）

    private func syncDisplayCaffeinate() {
        let shouldRun = controlDisplaySleep && sleepDisabled
        if shouldRun {
            if caffeinate?.isRunning != true {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
                process.arguments = ["-d"] // ディスプレイのスリープを防ぐ
                try? process.run()
                caffeinate = process
            }
        } else {
            if caffeinate?.isRunning == true { caffeinate?.terminate() }
            caffeinate = nil
        }
    }

    // MARK: - ログイン時に起動（SMAppService）

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Adderall: ログイン項目の変更に失敗: \(error)")
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: - sudoers セットアップ（管理者ダイアログを1度だけ出す）

    /// 対象コマンドだけを無パスワード許可する sudoers を /etc/sudoers.d に書き込む。
    func setupSudoers() {
        let user = NSUserName()
        let file = "/etc/sudoers.d/adderall-disablesleep"
        let content = """
        # Adderall — pmset disablesleep をパスワードなしで実行する許可
        \(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
        \(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
        """
        // visudo で文法チェックしてから設置する。
        let shell = """
        tmp=$(mktemp) && cat > "$tmp" <<'SUDOERS'
        \(content)
        SUDOERS
        visudo -cf "$tmp" && install -m 0440 -o root -g wheel "$tmp" '\(file)'; rm -f "$tmp"
        """
        runAsAdmin(shell)
        refresh()
    }

    private func runAsAdmin(_ shellCommand: String) {
        // AppleScript 経由で GUI の管理者パスワードダイアログを出す。
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        Shell.run("/usr/bin/osascript", ["-e", appleScript])
    }

    // MARK: - 後始末

    func cleanup() {
        if caffeinate?.isRunning == true { caffeinate?.terminate() }
        caffeinate = nil
    }
}
