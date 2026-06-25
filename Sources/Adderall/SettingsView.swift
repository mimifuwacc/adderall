import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: Updater

    private var updateStatusText: String {
        switch updater.status {
        case .idle: return "バージョン \(updater.currentVersion)"
        case .checking: return "確認中…"
        case .upToDate: return "最新です（\(updater.currentVersion)）"
        case .available(let v): return "新しいバージョン \(v) があります"
        case .downloading: return "ダウンロード中…"
        case .failed: return "バージョン \(updater.currentVersion)"
        }
    }

    private var isBusy: Bool {
        updater.status == .checking || updater.status == .downloading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adderall 設定")
                .font(.headline)

            Toggle("ログイン時に起動", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Toggle("ディスプレイのスリープも防ぐ", isOn: $model.controlDisplaySleep)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: model.sudoersConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(model.sudoersConfigured ? .green : .red)
                Text(model.sudoersConfigured
                     ? "パスワードなし実行: 設定済み"
                     : "パスワードなし実行: 未設定")
                Spacer()
                if !model.sudoersConfigured {
                    Button("設定する") { model.setupSudoers() }
                }
            }

            Text("「設定する」を押すと、pmset の disablesleep だけをパスワードなしで実行できるよう /etc/sudoers.d に登録します（管理者パスワードを1度だけ入力）。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 8) {
                Text(updateStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if isBusy { ProgressView().controlSize(.small) }
                Spacer()
                Button("アップデートを確認") { updater.check(silent: false) }
                    .disabled(isBusy)
            }

            HStack {
                Text("メニューバーのアイコンをクリックで ON/OFF を切り替えます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Adderall を終了") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
