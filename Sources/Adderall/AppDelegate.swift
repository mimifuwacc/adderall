import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
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
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

    // MARK: - クリック処理

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        if !model.toggle() {
            presentSudoError()
        }
        updateIcon()
    }

    private func showMenu() {
        let menu = NSMenu()

        let statusTitle = model.sleepDisabled ? "状態: スリープ無効（起動継続）" : "状態: スリープ許可"
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        let toggleTitle = model.sleepDisabled ? "スリープを許可する" : "スリープを無効にする"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ","))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Adderall を終了", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        // メニューを一時的に割り当てて開く。閉じたら外して左クリックのトグルに戻す。
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleFromMenu() { toggle() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Adderall 設定"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 見た目

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        // 起動継続中=目を開く、スリープ許可=目を閉じる。テンプレート画像でメニューバーに馴染ませる。
        let symbol = model.sleepDisabled ? "eye.fill" : "eye.slash"
        let description = model.sleepDisabled ? "スリープ無効（起動継続中）" : "スリープ許可"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        // 画像が出ない環境でも必ず見えるよう記号をフォールバックに置く。
        button.title = image == nil ? (model.sleepDisabled ? "◉" : "◌") : ""
        button.imagePosition = .imageOnly
        button.toolTip = "Adderall — \(description)\n左クリック: 切替 / 右クリック: メニュー"
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
