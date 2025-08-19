#!/bin/bash
# Simple commit window implementation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Simple commit window function
show_ai_commit_window() {
    local ai_message="$1"
    
    log_info "🖥️  コミットメッセージ編集を開始..."
    
    # メッセージが空でないかチェック
    if [[ -z "$ai_message" ]]; then
        log_error "❌ AI生成メッセージが空です"
        return 1
    fi
    
    # ログメッセージを除去してクリーンなメッセージを抽出
    ai_message=$(echo "$ai_message" | \
        grep -v "^\[20[0-9][0-9]-" | \
        grep -v "INFO" | \
        grep -v "DEBUG" | \
        grep -v "WARN" | \
        grep -v "ERROR" | \
        grep -v "Gemini CLI" | \
        grep -v "プロンプト" | \
        grep -v "レスポンス" | \
        grep -v "実行中" | \
        grep -v "送信中" | \
        grep -v "受信" | \
        grep -v "処理中" | \
        grep -v "生成" | \
        grep -v "完了" | \
        head -1 | \
        sed 's/^[[:space:]]*//' | \
        sed 's/[[:space:]]*$//')
    
    # サニタイズ後も空の場合はデフォルトメッセージ
    if [[ -z "$ai_message" ]]; then
        ai_message="ファイルを更新"
    fi
    
    # 簡単な確認ダイアログを表示
    echo "AI生成されたコミットメッセージ:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$ai_message"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "このメッセージでコミットしますか？"
    echo "  y: はい、このメッセージでコミット"
    echo "  e: エディターで編集"
    echo "  n: キャンセル"
    echo -n "選択してください [y/e/n]: "
    
    local choice
    read -r choice
    
    case "$choice" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            echo "$ai_message"
            return 0
            ;;
        "e"|"E"|"edit"|"Edit"|"EDIT")
            # エディターで編集
            local temp_file="/tmp/ai-commit-message-edit.txt"
            echo "$ai_message" > "$temp_file"
            
            # 利用可能なエディターを試す
            local editors=("nano" "vim" "vi" "emacs")
            local editor_found=false
            
            for editor in "${editors[@]}"; do
                if command -v "$editor" >/dev/null 2>&1; then
                    log_info "エディター '$editor' を使用してメッセージを編集中..."
                    if "$editor" "$temp_file"; then
                        local edited_message
                        edited_message=$(cat "$temp_file")
                        rm -f "$temp_file"
                        echo "$edited_message"
                        return 0
                    fi
                    editor_found=true
                    break
                fi
            done
            
            if ! $editor_found; then
                log_error "利用可能なエディターが見つかりません"
                echo "$ai_message"
                return 0
            fi
            ;;
        *)
            log_info "ユーザーによってキャンセルされました"
            return 1
            ;;
    esac
}

# Commit confirmation function
confirm_and_commit() {
    local message="$1"
    local skip_confirmation="${2:-false}"
    
    # メッセージが空でないかチェック
    if [[ -z "$message" || "$message" =~ ^[[:space:]]*$ ]]; then
        log_error "❌ コミットメッセージが空です"
        echo "❌ エラー: コミットメッセージが空です"
        return 1
    fi
    
    # ステージされたファイルがあるかチェック
    if git diff --cached --quiet; then
        log_error "❌ ステージされたファイルがありません"
        echo "❌ エラー: ステージされたファイルがありません"
        return 1
    fi
    
    # Lazygitモード用：確認を簡略化
    if [[ "$skip_confirmation" == "true" ]] || [[ "${LAZYGIT_MODE:-false}" == "true" ]]; then
        echo
        echo "📝 最終コミットメッセージ:"
        echo "=================================="
        echo "$message"
        echo "=================================="
        echo
    else
        echo
        echo "コミットメッセージ: $message"
        echo -n "このメッセージでコミットしますか？ [Y/n]: "
        read -r response
        
        case "$response" in
            ""|"y"|"Y"|"yes"|"Yes"|"YES")
                ;;
            *)
                echo "❌ コミットがキャンセルされました"
                return 1
                ;;
        esac
    fi
    
    log_info "🚀 Gitコミットを実行中..."
    if git commit -m "$message"; then
        echo "✅ コミット完了！"
        log_info "✅ コミット成功: $message"
        return 0
    else
        echo "❌ コミットに失敗しました"
        log_error "❌ Gitコミットに失敗しました"
        return 1
    fi
}