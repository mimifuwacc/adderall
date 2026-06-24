import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

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
