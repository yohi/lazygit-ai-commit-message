#!/bin/bash
# Lazygit設定統合スクリプト

set -euo pipefail

echo "🔧 Lazygit設定統合スクリプト"
echo "================================"

# 設定ディレクトリの確認・作成
CONFIG_DIR="$HOME/.config/lazygit"
CONFIG_FILE="$CONFIG_DIR/config.yml"

echo "📁 設定ディレクトリを確認中..."
if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "⚠️  Lazygit設定ディレクトリが存在しません。作成します..."
    mkdir -p "$CONFIG_DIR"
    echo "✅ ディレクトリを作成しました: $CONFIG_DIR"
else
    echo "✅ ディレクトリが存在します: $CONFIG_DIR"
fi

# 既存設定ファイルの確認
if [[ -f "$CONFIG_FILE" ]]; then
    echo "⚠️  既存の設定ファイルが見つかりました: $CONFIG_FILE"
    echo "🔄 バックアップを作成します..."
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ バックアップ完了"
    
    # 既存のcustomCommandsセクションをチェック
    if grep -q "customCommands:" "$CONFIG_FILE"; then
        echo "📝 既存のcustomCommandsセクションが見つかりました"
        echo "⚠️  手動で設定を統合してください"
        echo ""
        echo "以下の設定を$CONFIG_FILEのcustomCommandsセクションに追加してください："
        echo "----------------------------------------"
        cat "$(dirname "$0")/config/lazygit.yml" | grep -A 20 "customCommands:"
        echo "----------------------------------------"
        exit 0
    fi
fi

# 設定ファイルをコピー
echo "📋 AI Commit Generator設定をコピー中..."
if [[ -f "$(dirname "$0")/config/lazygit.yml" ]]; then
    cp "$(dirname "$0")/config/lazygit.yml" "$CONFIG_FILE"
    echo "✅ 設定ファイルをコピーしました: $CONFIG_FILE"
else
    echo "❌ エラー: 設定ファイルが見つかりません: $(dirname "$0")/config/lazygit.yml"
    exit 1
fi

echo ""
echo "🎉 設定統合完了！"
echo ""
echo "📋 次の手順："
echo "1. Lazygitを起動してください: lazygit"
echo "2. ファイルをステージしてください"
echo "3. Ctrl+G を押してAI生成を試してください"
echo ""
echo "🐛 トラブルシューティング:"
echo "- それでもシェルに遷移する場合は、Lazygitのバージョンを確認してください"
echo "- lazygit --version"
echo "- 最新バージョンにアップデートすることをお勧めします"
echo ""
echo "📚 設定ファイル場所: $CONFIG_FILE"
echo "🔍 設定内容を確認: cat $CONFIG_FILE"