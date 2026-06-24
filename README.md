# Adderall

`sudo pmset -a disablesleep` をメニューバーからワンクリックで切り替えるだけの macOS アプリ。

- **アイコンをクリック**: スリープ無効 ⇄ 許可 をトグル
- **`.app` をもう一度起動**: 設定ウィンドウを開く（常駐中に再度開く操作で reopen）
- アイコンで状態が分かる（👁 開いた目 = 起動継続中 / 👁̸ 閉じた目 = スリープ許可）
- 普段は Dock に出ず、メニューバーだけに常駐（設定を開いている間だけ Dock に表示）

## 設定画面

メニューバーに常駐した状態で `.app` をもう一度起動すると設定ウィンドウが開きます:

- **ログイン時に起動** — `SMAppService` でログイン項目に登録/解除
- **ディスプレイのスリープも防ぐ** — 有効中は `caffeinate -d` でディスプレイも起こし続ける（root 不要・可逆）
- **パスワードなし実行の状態** — ✓/✗ で表示。未設定なら「設定する」ボタンから管理者ダイアログ1回で登録
- **Adderall を終了** — 終了ボタン（メニューが無いのでここから終了）

## セットアップ

### 1. パスワードなし実行を許可（初回のみ）

`disablesleep` は root 権限が必要なため、対象コマンドだけを sudoers でパスワード不要にします。
アプリの「設定…」→「設定する」か、ターミナルで:

```sh
./scripts/install-sudoers.sh
```

`/etc/sudoers.d/adderall-disablesleep` に以下だけを登録します（pmset の他の操作は許可しません）:

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
```

解除したいときは `sudo rm /etc/sudoers.d/adderall-disablesleep`。

### 2. ビルドして起動

```sh
./scripts/build-app.sh
open Adderall.app
```

> 実行ファイルを直接叩くとメニューバーに出ないことがあるため、必ず `open` で起動してください。

## リリース / ダウンロード版

GitHub で **Release を publish すると** `.github/workflows/release.yml` が動き、`Adderall.app` を
ビルドして `/Applications` シンボリックリンク同梱の DMG（`Adderall-<tag>.dmg`）を Release に添付します。
DMG を開いて Adderall を Applications にドラッグするだけでインストールできます。

リリース手順の例:

```sh
gh release create v0.1.0 --generate-notes
# publish 後、Actions が DMG をビルドして Release に添付します
```

> push / PR では `build.yml` がビルド検証だけ行い、`Adderall.zip` を Actions のアーティファクトに残します。

配布物は **ad-hoc 署名**（公証なし）のため、初回起動時に Gatekeeper の警告が出ます。回避方法:

- Finder で `Adderall.app` を右クリック →「開く」、または
- `xattr -dr com.apple.quarantine /Applications/Adderall.app`

## 仕組み

- 状態取得は `pmset -g` の `SleepDisabled` 行を読む（root 不要）
- 切り替えは `sudo -n /usr/bin/pmset -a disablesleep {0,1}`（無パスワード前提、未設定なら案内ダイアログ）
- 許可の有無は `sudo -n -l ...` で実行せずに判定
- ディスプレイは `caffeinate -d` を起動/終了して制御
- 5 秒ごとに状態を再取得し、ターミナル等での変更にも追従

## 開発

```sh
swift build          # デバッグビルド
./scripts/build-app.sh && open Adderall.app
```
