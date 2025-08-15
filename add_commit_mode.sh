#!/bin/bash
# Lazygit設定にcommit-mode用コマンドを追加するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔧 commit-mode用コマンドを追加中..."
echo "=================================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.commit.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

echo "🔄 commit-mode用コマンドを追加中..."

# Python3でcommit-mode用コマンドを追加
cat > /tmp/add_commit_mode.py << 'EOF'
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

# commit-mode用コマンドを追加
commit_commands = [
    {
        'key': '<c-a>',
        'context': 'files',
        'command': f'{script_dir}/ai-commit-generator --commit-mode',
        'description': 'AI生成 + 自動コミット',
        'loadingText': 'AIコミットメッセージ生成中...',
        'output': 'terminal',  # コミットエディタを開くためterminalが必要
        'prompts': [
            {
                'type': 'confirm',
                'title': 'AI生成 + 自動コミット',
                'body': 'AIがメッセージを生成し、自動でコミットエディタを開きます。続行しますか？'
            }
        ]
    }
]

# 既存のコマンドと重複チェック
existing_keys = {cmd.get('key') for cmd in config['customCommands'] if isinstance(cmd, dict)}

for cmd in commit_commands:
    if cmd['key'] not in existing_keys:
        config['customCommands'].append(cmd)
        print(f"追加: {cmd['key']} - {cmd['description']}")
    else:
        print(f"スキップ（重複）: {cmd['key']} - {cmd['description']}")

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)

print("✅ commit-mode用コマンド追加完了")
EOF

# Pythonで設定を更新
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/add_commit_mode.py "$CONFIG_FILE" "$0"
    rm /tmp/add_commit_mode.py
    echo "✅ Python3でコマンド追加完了"
else
    echo "❌ Python3が見つかりません。手動追加が必要です"
    rm /tmp/add_commit_mode.py
    exit 1
fi

echo ""
echo "🎉 追加完了！"
echo ""
echo "📋 追加されたコマンド:"
echo "- Ctrl+A: AI生成 + 自動コミット（ワンステップ）"
echo ""
echo "📚 使用方法:"
echo "1. ファイルをステージ"
echo "2. Ctrl+A を押す"
echo "3. AIが生成し、自動でコミットエディタが開く"
echo "4. メッセージを確認・編集してコミット完了"
echo ""
echo "💡 従来方式との比較:"
echo "- Ctrl+G: AI生成のみ（手動でコミット画面を開く）"
echo "- Ctrl+A: AI生成 + 自動コミットエディタ起動"
echo ""
echo "🔍 更新後の設定:"
echo "----------------------------------------"
grep -A 10 -B 2 "commit-mode" "$CONFIG_FILE" || echo "設定が見つかりません"
echo "----------------------------------------"
echo ""
echo "📄 バックアップ: $BACKUP_FILE"