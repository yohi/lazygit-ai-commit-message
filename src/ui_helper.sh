#!/bin/bash
# UI表示とフィードバック機能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config_loader.sh"

# スピナー関連
SPINNER_PID=""
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# スピナーを開始
start_spinner() {
    local message="${1:-処理中...}"
    local config=$(load_config)
    local show_spinner=$(echo "$config" | jq -r '.ui.show_spinner // true')
    
    if [[ "$show_spinner" != "true" ]]; then
        echo "$message"
        return 0
    fi
    
    {
        local i=0
        while true; do
            local char="${SPINNER_CHARS:$((i % ${#SPINNER_CHARS})):1}"
            printf "\r%s %s" "$char" "$message"
            sleep 0.1
            ((i++))
        done
    } &
    
    SPINNER_PID=$!
    log_debug "スピナーを開始しました（PID: $SPINNER_PID）"
}

# スピナーを停止
stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r"
        log_debug "スピナーを停止しました"
    fi
}

# 確認ダイアログを表示
show_confirmation() {
    local title="$1"
    local message="$2"
    local config=$(load_config)
    local confirmation_required=$(echo "$config" | jq -r '.ui.confirmation_required // true')
    
    if [[ "$confirmation_required" != "true" ]]; then
        return 0
    fi
    
    echo "=== $title ==="
    echo "$message"
    echo
    read -p "続行しますか？ [y/N]: " -r
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "ユーザーによってキャンセルされました"
        return 1
    fi
    
    return 0
}

# 成功メッセージを表示
show_success() {
    local message="$1"
    echo "✅ $message"
    log_info "成功: $message"
}

# エラーメッセージを表示
show_error() {
    local message="$1"
    echo "❌ $message" >&2
    log_error "$message"
}

# 警告メッセージを表示
show_warning() {
    local message="$1"
    echo "⚠️  $message"
    log_warn "$message"
}

# 情報メッセージを表示
show_info() {
    local message="$1"
    echo "ℹ️  $message"
    log_info "$message"
}

# プログレスバーを表示（簡易版）
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-}"
    
    local percentage=$((current * 100 / total))
    local bar_length=20
    local filled_length=$((percentage * bar_length / 100))
    
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    printf "\r[%s] %d%% %s" "$bar" "$percentage" "$message"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# メッセージをLazygitに返す
return_to_lazygit() {
    local commit_message="$1"
    
    # Lazygitのコミットメッセージとして返す
    echo "$commit_message"
    
    log_info "メッセージをLazygitに返しました: $commit_message"
}

# クリーンアップ処理
cleanup_ui() {
    stop_spinner
    
    # カーソルを表示
    printf "\033[?25h"
    
    log_debug "UI クリーンアップ完了"
}

# シグナルハンドラー設定
setup_signal_handlers() {
    trap cleanup_ui EXIT
    trap cleanup_ui INT
    trap cleanup_ui TERM
}

# エラーハンドリング付きでコマンドを実行
run_with_spinner() {
    local command="$1"
    local message="$2"
    
    start_spinner "$message"
    
    local result
    if result=$(eval "$command" 2>&1); then
        stop_spinner
        show_success "完了"
        echo "$result"
        return 0
    else
        stop_spinner
        show_error "失敗: $result"
        return 1
    fi
}

# ユーザー入力を取得
get_user_input() {
    local prompt="$1"
    local default_value="${2:-}"
    local validation_regex="${3:-.*}"
    
    local input
    while true; do
        if [[ -n "$default_value" ]]; then
            read -p "$prompt [$default_value]: " -r input
            input="${input:-$default_value}"
        else
            read -p "$prompt: " -r input
        fi
        
        if [[ $input =~ $validation_regex ]]; then
            echo "$input"
            return 0
        else
            show_error "無効な入力です。再度入力してください。"
        fi
    done
}

# スクリプトが直接実行された場合（テスト用）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_signal_handlers
    
    case "${1:-}" in
        "spinner")
            start_spinner "テスト中..."
            sleep 3
            stop_spinner
            show_success "テスト完了"
            ;;
        "confirm")
            if show_confirmation "テスト確認" "これはテストメッセージです"; then
                show_success "確認されました"
            else
                show_info "キャンセルされました"
            fi
            ;;
        "progress")
            for i in {1..10}; do
                show_progress "$i" 10 "処理中..."
                sleep 0.2
            done
            ;;
        *)
            echo "使用方法: $0 [spinner|confirm|progress]"
            ;;
    esac
fi