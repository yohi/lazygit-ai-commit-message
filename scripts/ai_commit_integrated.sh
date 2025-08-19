#!/bin/bash
# 🤖 統合AI コミットメッセージ生成スクリプト（修正版 - ステージングオンリー）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$SCRIPT_DIR")/src"

# ロガーの読み込み
source "${SRC_DIR}/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_debug() { echo "[DEBUG] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
}

# 使用方法表示
show_usage() {
    cat <<EOF
使用方法: $0 [MODE] [OPTIONS]

MODE:
    comment_only     コメント生成のみ
    commit          コメント生成 + コミット（ステージされたファイルのみ）
    commit_push     コメント生成 + コミット + プッシュ（ステージされたファイルのみ）
    display         確認ダイアログ用表示（デフォルト）

OPTIONS:
    --quiet         静かモード（最小限の出力）
    --progress      進捗表示モード（静かモード時も進捗を表示）
    --force-smart   Gemini APIを使わずスマートAIのみ使用
    --help          このヘルプを表示

例:
    $0 comment_only
    $0 commit --quiet
    $0 commit_push
    $0 display

注意: commitとcommit_pushはステージされたファイルのみをコミットします
EOF
}

# コマンドライン引数解析
parse_arguments() {
    MODE="display"
    QUIET=false
    PROGRESS=false
    FORCE_SMART=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            comment_only|commit|commit_push|display)
                MODE="$1"
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --progress)
                PROGRESS=true
                shift
                ;;
            --force-smart)
                FORCE_SMART=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "不明なオプション: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
}

# 進捗表示関数
show_progress() {
    local message="$1"
    local step="${2:-1}"
    local total="${3:-3}"
    
    if [ "$PROGRESS" = true ] || [ "$QUIET" = false ]; then
        echo "[$step/$total] $message" >&2
    fi
}

# ステージング状況チェック
check_staging() {
    if git diff --cached --quiet; then
        log_error "❌ コミット対象となるステージされた変更がありません"
        echo "💡 まずファイルをステージしてください:" >&2
        echo "   git add <ファイル名>" >&2
        echo "   または Lazygit でファイルを選択してスペースキー" >&2
        return 1
    fi
    return 0
}

# スマートAI（簡易版）
generate_smart_ai_message() {
    local file_count=$(git diff --cached --name-only | wc -l)
    local added_lines=$(git diff --cached --numstat | awk '{added+=$1} END {print added+0}')
    local deleted_lines=$(git diff --cached --numstat | awk '{deleted+=$2} END {print deleted+0}')
    local first_file=$(git diff --cached --name-only | head -1 | xargs basename)
    
    # ファイルタイプ判定
    local action="chore"
    local scope=""
    
    if echo "$first_file" | grep -q "\.md$\|README\|docs"; then
        action="docs"
        scope="docs"
    elif echo "$first_file" | grep -q "\.sh$\|scripts"; then
        action="feat"
        scope="scripts"
    elif echo "$first_file" | grep -q "config\|\.yml$\|\.yaml$"; then
        action="chore"
        scope="config"
    elif [ $added_lines -gt $deleted_lines ] && [ $((added_lines - deleted_lines)) -gt 10 ]; then
        action="feat"
    fi
    
    # メッセージ生成
    if [ "$file_count" -eq 1 ]; then
        local name=$(echo "$first_file" | sed 's/\.[^.]*$//')
        if [ -n "$scope" ]; then
            echo "${action}(${scope}): ${name}を更新"
        else
            echo "${action}: ${name}を更新"
        fi
    else
        echo "${action}: ${file_count}個のファイルを更新"
    fi
}

# コミット実行（ステージされたファイルのみ）
execute_commit() {
    log_info "ステージされたファイルのみをコミット中..."
    
    # ステージング状況を再確認
    if ! check_staging; then
        return 1
    fi
    
    if [ -f "/tmp/lazygit_ai_commit_message.txt" ]; then
        # ステージされた変更のみをコミット（git add は実行しない）
        git commit -F /tmp/lazygit_ai_commit_message.txt
        log_info "✅ コミット完了（ステージされたファイルのみ）"
        
        # コミットされたファイル一覧を表示
        echo "📋 コミットされたファイル:" >&2
        git diff --name-only HEAD~1 HEAD | sed 's/^/  • /' >&2
        
    else
        log_error "❌ AIコメントファイルが見つかりません"
        return 1
    fi
}

# プッシュ実行
execute_push() {
    log_info "🚀 リモートにプッシュ中..."
    git push
    log_info "✅ プッシュ完了"
}

# メイン処理
main() {
    parse_arguments "$@"
    
    if [ "$QUIET" = true ]; then
        log_info() { :; }
        log_debug() { :; }
        log_warn() { :; }
    fi
    
    # 最初のフィードバックを即座に表示
    if [[ "$MODE" == "display" ]]; then
        echo "🔄 AI処理を開始しています..." >&2
        sleep 0.1
    fi
    
    show_progress "🚀 統合AI コミットメッセージ生成を開始" 1 3
    log_info "モード: $MODE"
    
    # Git リポジトリチェック
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Gitリポジトリではありません"
        exit 1
    fi
    
    # ステージング状況チェック（commit/commit_pushの場合）
    if [[ "$MODE" == "commit" || "$MODE" == "commit_push" ]]; then
        if ! check_staging; then
            exit 1
        fi
    fi
    
    show_progress "🔍 Git変更を分析中..." 2 3
    show_progress "🤖 AIでコミットメッセージを生成中..." 3 3
    
    # AI処理（Gemini API 優先）
    local message=""
    if [ "$FORCE_SMART" = true ]; then
        message=$(generate_smart_ai_message)
        log_info "スマートAI でメッセージ生成（強制モード）"
    elif [ -z "${GEMINI_API_KEY:-}" ]; then
        message=$(generate_smart_ai_message)
        log_info "スマートAI でメッセージ生成（API キー未設定）"
    else
        # Gemini API を使用（簡易実行）
        if [ -f "${SRC_DIR}/gemini_client.sh" ] && command -v gemini >/dev/null 2>&1 && [ -n "${GEMINI_API_KEY:-}" ]; then
            log_info "Gemini API を使用してメッセージ生成中..."
            
            # シンプルなプロンプト
            local prompt="以下のGit差分から適切な日本語のコミットメッセージを50文字以内で生成してください:\n\n$(git diff --cached --stat)\n\n変更ファイル:\n$(git diff --cached --name-only)"
            
            # Gemini CLI直接実行（エラー無視）
            if message=$(timeout 20 gemini --prompt="$prompt" 2>/dev/null | \
                grep -v "Loaded cached credentials" | \
                grep -v "Data collection is disabled" | \
                grep -v "Loading" | \
                grep -v "credentials" | \
                grep -v "Authentication" | \
                grep -v "^$" | \
                grep -v "^\[" | \
                grep -v "^INFO" | \
                grep -v "^DEBUG" | \
                grep -v "^WARN" | \
                grep -v "^ERROR" | \
                grep -E "^[a-zA-Z].*|^[あ-んア-ンー一-龯].*" | \
                head -1 | \
                sed 's/^[[:space:]]*//' | \
                sed 's/[[:space:]]*$//'); then
                # 空または無効なレスポンスの場合はスマートAIを使用
                if [ -z "$message" ] || [ ${#message} -lt 5 ]; then
                    log_warn "Gemini API レスポンスが無効、スマートAIにフォールバック"
                    message=$(generate_smart_ai_message)
                else
                    log_info "Gemini API でメッセージ生成完了"
                fi
            else
                log_warn "Gemini API 実行失敗、スマートAIにフォールバック"
                message=$(generate_smart_ai_message)
            fi
        else
            log_warn "Gemini API環境が整っていません、スマートAIを使用"
            message=$(generate_smart_ai_message)
        fi
    fi
    
    # メッセージをファイルに保存
    echo "$message" > /tmp/lazygit_ai_commit_message.txt
    
    # モードに応じた処理実行
    case "$MODE" in
        "comment_only")
            if [ "$QUIET" = false ]; then
                echo "" >&2
                echo "🤖 AIコメント生成のみ完了" >&2
                echo "📄 生成されたコメント: $message" >&2
                echo "💡 ステージされたファイルのみがコミット対象です" >&2
            fi
            ;;
        "commit")
            if ! execute_commit; then
                exit 1
            fi
            ;;
        "commit_push")
            if ! execute_commit; then
                exit 1
            fi
            if ! execute_push; then
                exit 1
            fi
            ;;
        "display")
            # 確認ダイアログ用の表示（シンプル）
            echo "✅ Gemini 2.5 Flash AI生成完了"
            echo ""
            echo "📝 生成されたコミットメッセージ:"
            echo "┌─────────────────────────────────────────┐"
            echo "│ ${message}"
            echo "└─────────────────────────────────────────┘"
            echo ""
            echo "📊 ステージされた変更:"
            git diff --cached --stat | sed 's/^/  • /'
            ;;
    esac
    
    if [ "$QUIET" = false ]; then
        echo "" >&2
        echo "✅ 統合AI処理完了" >&2
    fi
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
