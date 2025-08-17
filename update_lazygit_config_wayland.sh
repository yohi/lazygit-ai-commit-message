#!/bin/bash
# Lazygit設定更新スクリプト（Wayland対応版）
# ユーザーのLazygit設定ファイルにWayland対応コマンドを追加

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/lazygit.yml"
USER_CONFIG_DIR="${HOME}/.config/lazygit"
USER_CONFIG_FILE="${USER_CONFIG_DIR}/config.yml"

echo "🔧 Lazygit設定更新 - Wayland対応版"
echo ""

# 設定ディレクトリを作成
if [[ ! -d "$USER_CONFIG_DIR" ]]; then
    echo "📁 Lazygit設定ディレクトリを作成: $USER_CONFIG_DIR"
    mkdir -p "$USER_CONFIG_DIR"
fi

# 既存設定のバックアップ
if [[ -f "$USER_CONFIG_FILE" ]]; then
    backup_file="${USER_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "💾 既存設定をバックアップ: $backup_file"
    cp "$USER_CONFIG_FILE" "$backup_file"
fi

# 新しい設定を適用
echo "✅ Wayland対応設定を適用"
cp "$CONFIG_FILE" "$USER_CONFIG_FILE"

echo ""
echo "🎉 設定更新完了！"
echo ""
echo "📋 利用可能なコマンド:"
echo "  Ctrl+G: AIコミットメッセージ生成のみ"
echo "  Ctrl+A: AI生成 + 自動コミット画面（従来）"
echo "  Alt+C:  AI生成 + 確認付き直接コミット（Wayland対応・推奨）"
echo "  Ctrl+X: 環境変数チェック"
echo ""
echo "💡 Wayland環境では Alt+C を使用することを推奨します"
echo "💡 このコマンドはキー送信を使わず、確実に動作します"
echo ""
echo "🔄 Lazygitを再起動して設定を反映してください"
