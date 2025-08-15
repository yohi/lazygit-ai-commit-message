#!/bin/bash
# Ctrl+Gの設定を更新してLazygitコミット統合を追加するスクリプト

set -euo pipefail

CONFIG_FILE="$HOME/.config/lazygit/config.yml"

echo "🔧 Ctrl+G Lazygitコミット統合更新スクリプト"
echo "============================================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.ctrlg.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ バックアップ作成: $BACKUP_FILE"

echo "🔄 Ctrl+G設定を更新中..."

# Python3でCtrl+G設定を更新
cat > /tmp/update_ctrl_g.py << 'EOF'
import sys
import yaml
import os

# 設定ファイルを読み込み
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f) or {}

# customCommandsセクションを確認
if 'customCommands' in config and isinstance(config['customCommands'], list):
    script_dir = os.path.dirname(os.path.abspath(sys.argv[2]))
    
    for cmd in config['customCommands']:
        if isinstance(cmd, dict) and cmd.get('key') == '<c-g>':
            if 'ai-commit-generator' in cmd.get('command', ''):
                print(f"更新前: {cmd}")
                # --lazygit-commitオプションを追加
                cmd['command'] = f'{script_dir}/ai-commit-generator --lazygit-commit'
                cmd['description'] = 'AIコミットメッセージ生成（自動コミット画面）'
                cmd['loadingText'] = 'AI生成中... コミット画面を準備中...'
                # output設定を更新
                cmd['output'] = 'popup'
                print(f"更新後: {cmd}")
                break
    else:
        print("❌ Ctrl+G設定が見つかりませんでした")
        sys.exit(1)

# ファイルに書き戻し
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, indent=2)

print("✅ Ctrl+G設定更新完了")
EOF

# Pythonで設定を更新
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/update_ctrl_g.py "$CONFIG_FILE" "$0"
    rm /tmp/update_ctrl_g.py
    echo "✅ Python3で設定更新完了"
else
    echo "❌ Python3が見つかりません。手動更新が必要です"
    rm /tmp/update_ctrl_g.py
    exit 1
fi

echo ""
echo "🎉 更新完了！"
echo ""
echo "📋 更新内容:"
echo "- Ctrl+G: AI生成 + Lazygitコミット画面自動表示"
echo "- コマンド: --lazygit-commit オプション使用"
echo "- 動作: AI生成後、「c」キーでコミット画面が開く"
echo ""
echo "📚 新しい動作フロー:"
echo "1. Ctrl+G を押す"
echo "2. AI生成完了を待つ"
echo "3. 自動で「c」キーを押してコミット画面を開く"
echo "4. 生成されたメッセージを確認・編集"
echo "5. コミット実行"
echo ""
echo "💡 キーバインド一覧:"
echo "- Ctrl+G: AI生成 + Lazygitコミット画面（更新済み）"
echo "- Ctrl+A: AI生成 + 外部コミットエディタ"
echo "- Ctrl+X: 環境チェック"
echo ""
echo "🔍 更新後の設定:"
echo "----------------------------------------"
grep -A 12 -B 2 "lazygit-commit" "$CONFIG_FILE" || echo "設定が見つかりません"
echo "----------------------------------------"
echo ""
echo "📄 バックアップ: $BACKUP_FILE"