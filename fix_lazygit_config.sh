#!/bin/bash
# Lazygit設定を修正するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔧 Lazygit設定修正スクリプト"
echo "============================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.fix.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

echo "🔄 設定を修正中..."

# Python3で設定を修正
cat > /tmp/fix_lazygit_config.py << 'EOF'
import sys
import yaml

# 設定ファイルを読み込み
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f) or {}

# customCommandsセクションを確認
if 'customCommands' in config and isinstance(config['customCommands'], list):
    for cmd in config['customCommands']:
        if isinstance(cmd, dict) and cmd.get('key') == '<c-g>':
            # AI Commit Generatorのコマンドを修正
            if 'ai-commit-generator' in cmd.get('command', ''):
                print(f"修正前: {cmd}")
                cmd['command'] = 'ai-commit-generator --lazygit-mode'
                cmd['output'] = 'popup'  # terminalからpopupに変更
                # streamとshowOutputを削除または設定
                if 'stream' in cmd:
                    del cmd['stream']
                if 'showOutput' in cmd:
                    del cmd['showOutput']
                print(f"修正後: {cmd}")
        
        if isinstance(cmd, dict) and cmd.get('key') == '<c-x>':
            # 環境チェックコマンドも修正
            if 'ai-commit-generator' in cmd.get('command', ''):
                cmd['output'] = 'popup'  # terminalからpopupに変更
                if 'stream' in cmd:
                    del cmd['stream']
                if 'showOutput' in cmd:
                    del cmd['showOutput']

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)

print("✅ 設定修正完了")
EOF

# Pythonで設定を修正
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/fix_lazygit_config.py "$CONFIG_FILE"
    rm /tmp/fix_lazygit_config.py
    echo "✅ Python3で設定修正完了"
else
    echo "❌ Python3が見つかりません。手動修正が必要です"
    rm /tmp/fix_lazygit_config.py
    exit 1
fi

echo ""
echo "🎉 修正完了！"
echo ""
echo "📋 修正内容:"
echo "1. output: terminal → output: popup"
echo "2. command: ai-commit-generator → ai-commit-generator --lazygit-mode"
echo "3. stream, showOutput オプションを削除"
echo ""
echo "📚 次のステップ:"
echo "1. lazygitを起動"
echo "2. ファイルをステージ"
echo "3. Ctrl+G でAI生成をテスト"
echo ""
echo "🔍 修正後の設定ファイル:"
echo "----------------------------------------"
grep -A 10 -B 2 "ai-commit-generator" "$CONFIG_FILE" || echo "設定が見つかりません"
echo "----------------------------------------"
echo ""
echo "📄 バックアップ: $BACKUP_FILE"