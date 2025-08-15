#!/bin/bash
# Lazygit設定のloadingTextを更新するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔧 Lazygit loadingText更新スクリプト"
echo "===================================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.loading.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

echo "🔄 loadingTextを更新中..."

# Python3でloadingTextを追加
cat > /tmp/update_loading_text.py << 'EOF'
import sys
import yaml

# 設定ファイルを読み込み
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f) or {}

# customCommandsセクションを確認
if 'customCommands' in config and isinstance(config['customCommands'], list):
    for cmd in config['customCommands']:
        if isinstance(cmd, dict) and cmd.get('key') == '<c-g>':
            # AI Commit GeneratorのloadingTextを設定
            if 'ai-commit-generator' in cmd.get('command', ''):
                print(f"更新前: {cmd.get('description', 'N/A')}")
                cmd['loadingText'] = 'AIがコミットメッセージを生成中...'
                print(f"更新後: loadingText = {cmd['loadingText']}")
        
        if isinstance(cmd, dict) and cmd.get('key') == '<c-x>':
            # 環境チェックコマンドのloadingTextも設定
            if 'ai-commit-generator' in cmd.get('command', ''):
                cmd['loadingText'] = '環境設定をチェック中...'

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)

print("✅ loadingText更新完了")
EOF

# Pythonで設定を更新
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/update_loading_text.py "$CONFIG_FILE"
    rm /tmp/update_loading_text.py
    echo "✅ Python3でloadingText更新完了"
else
    echo "❌ Python3が見つかりません。手動更新が必要です"
    rm /tmp/update_loading_text.py
    exit 1
fi

echo ""
echo "🎉 更新完了！"
echo ""
echo "📋 変更内容:"
echo "- Ctrl+G: 'AIがコミットメッセージを生成中...'"
echo "- Ctrl+X: '環境設定をチェック中...'"
echo ""
echo "📚 次のステップ:"
echo "1. lazygitを起動"
echo "2. ファイルをステージ" 
echo "3. Ctrl+G を押して新しいメッセージを確認"
echo ""
echo "🔍 更新後の設定:"
echo "----------------------------------------"
grep -A 12 -B 2 "ai-commit-generator" "$CONFIG_FILE" | grep -E "(key|description|loadingText|command)" || echo "設定が見つかりません"
echo "----------------------------------------"
echo ""
echo "📄 バックアップ: $BACKUP_FILE"