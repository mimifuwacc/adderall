import AppKit

// Adderall — `sudo pmset -a disablesleep` をメニューバーから切り替えるだけのアプリ。
// メニューバーアイコンの左クリックでトグル、.app を再度起動すると設定ウィンドウが開く。

let app = NSApplication.shared
let model = AppModel()
let delegate = AppDelegate(model: model)
app.delegate = delegate
// Dock に出さず、メニューバーだけに常駐する。
app.setActivationPolicy(.accessory)
app.run()
