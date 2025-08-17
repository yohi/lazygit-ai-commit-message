#!/bin/bash
# Lazygit統合 - 確認付き直接コミット＋プッシュ
# ユーザー確認後にLazygit内で完結するコミット～プッシュフロー

set -euo pipefail

# ログファイル
LOG_FILE="/tmp/lazygit_direct_commit.log"

# ログ関数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

log_message "=== Lazygit直接コミット開始 ==="

# 引数からコミットメッセージを取得
COMMIT_MESSAGE="${1:-}"

if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "❌ エラー: コミットメッセージが指定されていません"
    log_message "エラー: コミットメッセージが空"
    exit 1
fi

log_message "受信したコミットメッセージ: $COMMIT_MESSAGE"

# 現在のGit状態を確認
if ! git diff --cached --quiet; then
    staged_files_count=$(git diff --cached --name-only | wc -l)
    log_message "ステージされたファイル数: $staged_files_count"
else
    echo "❌ エラー: ステージされたファイルがありません"
    log_message "エラー: ステージされたファイルなし"
    exit 1
fi

# ステージされたファイル一覧を表示
echo "📋 ステージされたファイル:"
git diff --cached --name-status | while read status file; do
    echo "  $status $file"
done

echo ""
echo "📝 AI生成コミットメッセージ:"
echo "─────────────────────────────"
echo "$COMMIT_MESSAGE"
echo "─────────────────────────────"
echo ""

# ユーザー確認
echo ""
echo "🤖 このメッセージでコミットしますか？"
echo ""
echo "オプション:"
echo "  [y] はい - このメッセージでコミット"
echo "  [e] 編集 - メッセージを編集してコミット"
echo "  [p] プッシュ付き - コミット後に自動プッシュ"
echo "  [n] いいえ - キャンセル"
echo ""

# 入力の準備ができるまで少し待つ
sleep 0.5

while true; do
    echo -n "選択してください [y/e/p/n]: "
    read -r choice
    case $choice in
        [Yy]*)
            # そのままコミット
            log_message "ユーザー選択: 直接コミット"
            if git commit -m "$COMMIT_MESSAGE"; then
                echo "✅ コミット完了！"
                log_message "コミット成功"

                # コミットハッシュを取得して表示
                commit_hash=$(git rev-parse --short HEAD)
                echo "📦 コミットハッシュ: $commit_hash"
                log_message "コミットハッシュ: $commit_hash"

                echo "💡 次のステップ: 'P'キーでプッシュできます"
                exit 0
            else
                echo "❌ コミットに失敗しました"
                log_message "コミット失敗"
                exit 1
            fi
            ;;
        [Ee]*)
            # メッセージ編集
            log_message "ユーザー選択: メッセージ編集"
            temp_file="/tmp/commit_message_edit.txt"
            echo "$COMMIT_MESSAGE" > "$temp_file"

            # エディタを選択（優先順位: VISUAL > EDITOR > nano）
            editor="${VISUAL:-${EDITOR:-nano}}"
            echo "📝 エディタでメッセージを編集中: $editor"

            if "$editor" "$temp_file"; then
                edited_message=$(cat "$temp_file")
                if [[ -n "$edited_message" ]] && [[ "$edited_message" != "" ]]; then
                    log_message "編集後メッセージ: $edited_message"
                    if git commit -m "$edited_message"; then
                        echo "✅ 編集後メッセージでコミット完了！"
                        log_message "編集後コミット成功"

                        commit_hash=$(git rev-parse --short HEAD)
                        echo "📦 コミットハッシュ: $commit_hash"

                        echo "💡 次のステップ: 'P'キーでプッシュできます"
                        rm -f "$temp_file"
                        exit 0
                    else
                        echo "❌ コミットに失敗しました"
                        log_message "編集後コミット失敗"
                        rm -f "$temp_file"
                        exit 1
                    fi
                else
                    echo "❌ メッセージが空です"
                    rm -f "$temp_file"
                    exit 1
                fi
            else
                echo "❌ エディタでの編集がキャンセルされました"
                rm -f "$temp_file"
                exit 1
            fi
            ;;
        [Pp]*)
            # コミット＋プッシュ
            log_message "ユーザー選択: コミット+プッシュ"
            if git commit -m "$COMMIT_MESSAGE"; then
                echo "✅ コミット完了！"
                log_message "コミット成功"

                commit_hash=$(git rev-parse --short HEAD)
                echo "📦 コミットハッシュ: $commit_hash"

                echo "🚀 プッシュ中..."
                if git push; then
                    echo "✅ プッシュ完了！"
                    log_message "プッシュ成功"
                    echo "🎉 コミット→プッシュが完了しました"
                    exit 0
                else
                    echo "⚠️  コミットは完了しましたが、プッシュに失敗しました"
                    echo "💡 手動で 'P'キーを押してプッシュしてください"
                    log_message "プッシュ失敗"
                    exit 0
                fi
            else
                echo "❌ コミットに失敗しました"
                log_message "コミット失敗"
                exit 1
            fi
            ;;
        [Nn]*)
            echo "❌ コミットがキャンセルされました"
            log_message "ユーザーキャンセル"
            exit 0
            ;;
        *)
            echo "無効な選択です。y, e, p, n のいずれかを入力してください。"
            ;;
    esac
done
