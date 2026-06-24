#!/bin/bash
# pmset の disablesleep をパスワードなしで切り替えられるように sudoers に登録する。
# 一度だけ実行すればよい。実行時に管理者パスワードを求められる。
# （アプリの「設定…」→「設定する」でも同じことができます）
set -euo pipefail

USER_NAME="$(whoami)"
DEST="/etc/sudoers.d/adderall-disablesleep"
TMP="$(mktemp)"

cat > "$TMP" <<EOF
# Adderall — pmset disablesleep をパスワードなしで実行する許可
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
EOF

# 文法チェック（壊れた sudoers を入れて sudo を使えなくしないため）。
if ! sudo visudo -cf "$TMP"; then
    echo "sudoers の文法チェックに失敗しました。中止します。" >&2
    rm -f "$TMP"
    exit 1
fi

sudo install -m 0440 -o root -g wheel "$TMP" "$DEST"
rm -f "$TMP"

echo "インストール完了: $DEST"
echo "確認: sudo -n -l /usr/bin/pmset -a disablesleep 1 が許可表示されれば OK"
