import AppKit

// Adderall — `sudo pmset -a disablesleep` をメニューバーから切り替えるだけのアプリ。
// 左クリックでトグル、右クリックでメニュー（設定・終了）。

let app = NSApplication.shared
let model = AppModel()
let delegate = AppDelegate(model: model)
app.delegate = delegate
// Dock に出さず、メニューバーだけに常駐する。
app.setActivationPolicy(.accessory)
app.run()
