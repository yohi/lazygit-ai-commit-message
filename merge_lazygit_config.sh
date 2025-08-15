#!/bin/bash
# 既存Lazygit設定にAI Commit Generatorを統合するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔍 既存のLazygit設定を確認中..."
echo "================================"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

echo "📋 既存設定の内容:"
echo "----------------------------------------"
cat "$CONFIG_FILE"
echo "----------------------------------------"
echo ""

echo "🤔 AI Commit Generator設定を統合しますか?"
echo "以下の設定を既存のcustomCommandsセクションに追加する必要があります:"
echo ""
echo "  - key: '<c-g>'"
echo "    context: 'files'"
echo "    command: 'ai-commit-generator --lazygit-mode'"
echo "    description: 'AIコミットメッセージ生成'"
echo "    stream: false"
echo "    showOutput: true"
echo "    prompts:"
echo "      - type: 'confirm'"
echo "        title: 'AIコミットメッセージ生成'"
echo "        body: '生成AIがコミットメッセージを作成します。続行しますか？'"
echo ""
echo "  - key: '<c-x>'"
echo "    context: 'files'"
echo "    command: 'ai-commit-generator --check-env'"
echo "    description: '環境変数チェック'"
echo "    stream: false"
echo "    showOutput: true"
echo ""

read -p "自動統合を実行しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ キャンセルされました"
    echo "手動で上記設定を $CONFIG_FILE に追加してください"
    exit 0
fi

echo "🔄 設定を統合中..."

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

# customCommandsセクションがあるかチェック
if grep -q "customCommands:" "$CONFIG_FILE"; then
    echo "📝 既存のcustomCommandsセクションに追加中..."
    
    # 一時ファイルを作成
    TEMP_FILE=$(mktemp)
    
    # 既存のcustomCommandsセクションにAI Commit Generator設定を追加
    cat > "$TEMP_FILE" << 'EOF'
import sys
import yaml

# 設定ファイルを読み込み
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f) or {}

# customCommandsセクションを確保
if 'customCommands' not in config:
    config['customCommands'] = []

# AI Commit Generator設定を追加
ai_commands = [
    {
        'key': '<c-g>',
        'context': 'files',
        'command': 'ai-commit-generator --lazygit-mode',
        'description': 'AIコミットメッセージ生成',
        'stream': False,
        'showOutput': True,
        'prompts': [
            {
                'type': 'confirm',
                'title': 'AIコミットメッセージ生成',
                'body': '生成AIがコミットメッセージを作成します。続行しますか？'
            }
        ]
    },
    {
        'key': '<c-x>',
        'context': 'files',
        'command': 'ai-commit-generator --check-env',
        'description': '環境変数チェック',
        'stream': False,
        'showOutput': True
    }
]

# 既存のコマンドと重複チェック
existing_keys = {cmd.get('key') for cmd in config['customCommands'] if isinstance(cmd, dict)}

for cmd in ai_commands:
    if cmd['key'] not in existing_keys:
        config['customCommands'].append(cmd)
        print(f"追加: {cmd['key']} - {cmd['description']}")
    else:
        print(f"スキップ（重複）: {cmd['key']} - {cmd['description']}")

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)
EOF

    # Pythonで設定を統合
    if command -v python3 >/dev/null 2>&1; then
        python3 "$TEMP_FILE" "$CONFIG_FILE"
        rm "$TEMP_FILE"
        echo "✅ Python3で設定統合完了"
    else
        echo "⚠️  Python3が見つかりません。手動統合が必要です"
        rm "$TEMP_FILE"
        echo "以下のコマンドを既存のcustomCommandsセクションに手動で追加してください："
        cat "$(dirname "$0")/config/lazygit.yml" | grep -A 15 "customCommands:" | tail -n +2
        exit 1
    fi
else
    echo "📝 customCommandsセクションを新規作成中..."
    # 既存設定の末尾にcustomCommandsセクションを追加
    cat >> "$CONFIG_FILE" << 'EOF'

# AI Commit Generator カスタムコマンド
customCommands:
  - key: '<c-g>'
    context: 'files'
    command: 'ai-commit-generator --lazygit-mode'
    description: 'AIコミットメッセージ生成'
    stream: false
    showOutput: true
    prompts:
      - type: 'confirm'
        title: 'AIコミットメッセージ生成'
        body: '生成AIがコミットメッセージを作成します。続行しますか？'
  - key: '<c-x>'
    context: 'files'
    command: 'ai-commit-generator --check-env'
    description: '環境変数チェック'
    stream: false
    showOutput: true
EOF
    echo "✅ customCommandsセクションを追加しました"
fi

echo ""
echo "🎉 設定統合完了！"
echo ""
echo "📋 統合後の設定:"
echo "----------------------------------------"
cat "$CONFIG_FILE"
echo "----------------------------------------"
echo ""
echo "📚 次のステップ:"
echo "1. lazygitを起動"
echo "2. ファイルをステージ"  
echo "3. Ctrl+G でAI生成をテスト"
echo ""
echo "🔍 設定ファイル: $CONFIG_FILE"
echo "📄 バックアップ: $BACKUP_FILE"