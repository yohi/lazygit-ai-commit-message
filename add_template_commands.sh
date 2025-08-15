#!/bin/bash
# Lazygit設定にテンプレート関連コマンドを追加するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔧 テンプレート関連コマンドを追加中..."
echo "================================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.template.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

echo "🔄 テンプレート関連コマンドを追加中..."

# Python3でテンプレート関連コマンドを追加
cat > /tmp/add_template_commands.py << 'EOF'
import sys
import yaml
import os

# 設定ファイルを読み込み
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f) or {}

# customCommandsセクションを確保
if 'customCommands' not in config:
    config['customCommands'] = []

# 現在のスクリプトディレクトリを取得
script_dir = os.path.dirname(os.path.abspath(sys.argv[2]))

# テンプレート関連コマンドを追加
template_commands = [
    {
        'key': '<c-t>',
        'context': 'files',
        'command': f'{script_dir}/clear_template.sh',
        'description': 'AIテンプレートをクリア',
        'loadingText': 'コミットテンプレートをクリア中...',
        'output': 'popup'
    }
]

# 既存のコマンドと重複チェック
existing_keys = {cmd.get('key') for cmd in config['customCommands'] if isinstance(cmd, dict)}

for cmd in template_commands:
    if cmd['key'] not in existing_keys:
        config['customCommands'].append(cmd)
        print(f"追加: {cmd['key']} - {cmd['description']}")
    else:
        print(f"スキップ（重複）: {cmd['key']} - {cmd['description']}")

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)

print("✅ テンプレート関連コマンド追加完了")
EOF

# Pythonで設定を更新
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/add_template_commands.py "$CONFIG_FILE" "$0"
    rm /tmp/add_template_commands.py
    echo "✅ Python3でコマンド追加完了"
else
    echo "❌ Python3が見つかりません。手動追加が必要です"
    rm /tmp/add_template_commands.py
    exit 1
fi

echo ""
echo "🎉 追加完了！"
echo ""
echo "📋 追加されたコマンド:"
echo "- Ctrl+T: AIテンプレートをクリア"
echo ""
echo "📚 使用方法:"
echo "1. Ctrl+G でAI生成（テンプレート設定）"
echo "2. 「c」キーでコミット画面を開く"
echo "3. コミット実行またはCtrl+Tでテンプレートクリア"
echo ""
echo "🔍 更新後の設定:"
echo "----------------------------------------"
grep -A 8 -B 2 "clear_template" "$CONFIG_FILE" || echo "設定が見つかりません"
echo "----------------------------------------"
echo ""
echo "📄 バックアップ: $BACKUP_FILE"