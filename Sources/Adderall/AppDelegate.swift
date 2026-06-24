import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem!
    private var pollTimer: Timer?
    private var settingsWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp])
        }
        updateIcon()

        // ターミナル等から状態が変わってもアイコンを追従させる。
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.model.refreshLive()
            self?.updateIcon()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.cleanup()
    }

    /// すでに常駐中のアプリをもう一度起動（.app をクリック）したら設定を開く。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: - クリック処理（左クリックでトグル）

    @objc private func handleClick() {
        if !model.toggle() {
            presentSudoError()
        }
        updateIcon()
    }

    // MARK: - 設定ウィンドウ

    private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Adderall 設定"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        model.refresh()
        // accessory のままだとウィンドウが前面に来ないため、開いている間だけ通常アプリ化する。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // 設定ウィンドウを閉じたらメニューバー常駐（Dock 非表示）に戻す。
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - 見た目

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        // 起動継続中=塗りつぶしの錠剤、スリープ許可=中空の錠剤。テンプレート画像でメニューバーに馴染ませる。
        let symbol = model.sleepDisabled ? "pills.fill" : "pills"
        let description = model.sleepDisabled ? "スリープ無効（起動継続中）" : "スリープ許可"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        if let image {
            // メニューバー（高さ22pt）に収まるよう高さ基準でサイズを固定する。
            // pointSize 指定だと pills は eye より縦に大きく、上下が切れてしまうため。
            let targetHeight: CGFloat = 16
            let aspect = image.size.width / max(image.size.height, 1)
            image.size = NSSize(width: targetHeight * aspect, height: targetHeight)
            image.isTemplate = true
        }
        button.image = image
        // 画像が出ない環境でも必ず見えるよう記号をフォールバックに置く。
        button.title = image == nil ? (model.sleepDisabled ? "◉" : "◌") : ""
        button.imagePosition = .imageOnly
        button.toolTip = "Adderall — \(description)\nクリック: 切替 / アプリを再起動: 設定"
    }

    private func presentSudoError() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "pmset の実行に失敗しました"
        alert.informativeText = """
        パスワードなしで pmset を実行する許可が設定されていません。
        設定画面の「設定する」ボタン、または scripts/install-sudoers.sh で一度だけ設定してください。
        """
        alert.addButton(withTitle: "設定を開く")
        alert.addButton(withTitle: "閉じる")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }
}
