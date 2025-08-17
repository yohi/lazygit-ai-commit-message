#!/bin/bash
# 代替コミットフロー - git直接実行版

set -euo pipefail

LOG_FILE="/tmp/alternative_commit.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "=== 代替コミットフロー開始 ==="

# コミットテンプレートの存在確認
COMMIT_TEMPLATE="/tmp/ai-commit-template.txt"
if [[ ! -f "$COMMIT_TEMPLATE" ]]; then
    log_message "❌ コミットテンプレートが見つかりません: $COMMIT_TEMPLATE"
    exit 1
fi

# AI生成メッセージを取得
AI_MESSAGE=$(cat "$COMMIT_TEMPLATE" | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

if [[ -z "$AI_MESSAGE" ]]; then
    log_message "❌ 空のコミットメッセージです"
    exit 1
fi

log_message "AI生成メッセージ: $AI_MESSAGE"

# ステージされたファイルの確認
STAGED_FILES=$(git diff --cached --name-only | wc -l)
if [[ "$STAGED_FILES" -eq 0 ]]; then
    log_message "❌ ステージされたファイルがありません"
    exit 1
fi

log_message "ステージされたファイル数: $STAGED_FILES"

# ユーザーに選択肢を提供
log_message "=== コミット実行方式の選択 ==="
echo ""
echo "選択肢:"
echo "1. 直接コミット実行 (git commit)"
echo "2. エディタでメッセージ編集 (git commit --edit)"
echo "3. lazygitに戻る（手動でcキー操作）"
echo ""

# 自動化モードの場合は選択肢1を選択
if [[ "${AUTO_COMMIT:-}" == "true" ]]; then
    choice="1"
    log_message "自動モード: 直接コミット実行を選択"
else
    read -p "選択してください (1/2/3): " choice
fi

case "$choice" in
    "1")
        log_message "直接コミット実行中..."
        if git commit -m "$AI_MESSAGE"; then
            log_message "✅ コミット完了"
            echo ""
            echo "🎉 コミットが正常に完了しました！"
            echo "メッセージ: $AI_MESSAGE"
        else
            log_message "❌ コミット失敗"
            exit 1
        fi
        ;;
    "2")
        log_message "エディタでメッセージ編集中..."
        
        # 一時ファイルにメッセージを保存
        TEMP_MSG="/tmp/edit-commit-msg.txt"
        echo "$AI_MESSAGE" > "$TEMP_MSG"
        
        # デフォルトエディタでメッセージを編集
        "${EDITOR:-nano}" "$TEMP_MSG"
        
        # 編集されたメッセージでコミット
        if git commit -F "$TEMP_MSG"; then
            log_message "✅ 編集後コミット完了"
            echo "🎉 編集されたメッセージでコミットが完了しました！"
            rm -f "$TEMP_MSG"
        else
            log_message "❌ 編集後コミット失敗"
            rm -f "$TEMP_MSG"
            exit 1
        fi
        ;;
    "3")
        log_message "lazygitに戻ります - 手動でcキーを押してください"
        echo ""
        echo "💡 lazygitで手動でcキーを押してコミット画面を開いてください"
        echo "AI生成メッセージ: $AI_MESSAGE"
        echo "（必要に応じてコピー&ペーストしてください）"
        ;;
    *)
        log_message "無効な選択です"
        exit 1
        ;;
esac

log_message "=== 代替コミットフロー完了 ==="