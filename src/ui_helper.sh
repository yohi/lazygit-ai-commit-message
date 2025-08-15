#!/bin/bash
# UI表示とフィードバック機能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config_loader.sh"

# スピナー関連
SPINNER_PID=""
# UTF-8スピナーフレーム
SPINNER_FRAMES_UTF8=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
# ASCII代替フレーム
SPINNER_FRAMES_ASCII=( "|" "/" "-" "\\" )

# UTF-8サポートを検出
is_utf8_supported() {
    case "${LC_CTYPE:-${LANG:-}}" in
        *UTF-8*|*utf8*) return 0 ;;
        *) return 1 ;;
    esac
}

# スピナーを開始
start_spinner() {
    local message="${1:-処理中...}"
    local show_spinner
    show_spinner=$(get_config_value ".ui.show_spinner" "true")
    
    if [[ "$show_spinner" != "true" ]]; then
        echo "$message"
        return 0
    fi
    
    # カーソルを隠す
    { tput civis || printf "\033[?25l"; } 2>/dev/null >&2
    
    {
        local i=0
        local frames
        if is_utf8_supported; then
            frames=( "${SPINNER_FRAMES_UTF8[@]}" )
        else
            frames=( "${SPINNER_FRAMES_ASCII[@]}" )
        fi
        
        while true; do
            local char="${frames[$((i % ${#frames[@]}))]}"
            printf "\r%s %s" "$char" "$message" >&2
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
        # 行をクリアしてカーソルを表示
        printf "\r\033[K" >&2
        { tput cnorm || printf "\033[?25h"; } 2>/dev/null >&2
        log_debug "スピナーを停止しました"
    fi
}

# 確認ダイアログを表示
show_confirmation() {
    local title="$1"
    local message="$2"
    local confirmation_required
    confirmation_required=$(get_config_value ".ui.confirmation_required" "true")
    
    if [[ "$confirmation_required" != "true" ]]; then
        return 0
    fi
    
    echo "=== $title ==="
    echo "$message"
    echo
    
    if ! read -p "続行しますか？ [y/N]: " -r; then
        REPLY=""
        echo >&2
        log_info "入力がキャンセルされました"
        return 1
    fi
    
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
    
    # 入力値検証
    if [[ ! "$total" =~ ^[0-9]+$ ]] || [[ "$total" -lt 0 ]]; then
        echo "エラー: totalは非負の整数である必要があります" >&2
        return 1
    fi
    
    if [[ ! "$current" =~ ^[0-9]+$ ]] || [[ "$current" -lt 0 ]]; then
        echo "エラー: currentは非負の整数である必要があります" >&2
        return 1
    fi
    
    # 特別ケース: total=0
    if [[ $total -eq 0 ]]; then
        printf "プログレス: アイテムなし\n" >&2
        return 0
    fi
    
    # currentがtotalを超えないようにする
    if [[ $current -gt $total ]]; then
        current="$total"
    fi
    
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
    
    printf "\r[%s] %d%% %s" "$bar" "$percentage" "$message" >&2
    
    if [[ $current -eq $total ]]; then
        echo >&2
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
    printf "\033[?25h" >&2
    
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
    local message="$1"
    shift
    
    # 一時ファイルを作成
    local temp_file
    temp_file=$(mktemp)
    if [[ ! -f "$temp_file" ]]; then
        echo "エラー: 一時ファイルの作成に失敗しました" >&2
        return 1
    fi
    
    # クリーンアップ用のtrap設定（EXITは保持、INT/TERMのみ設定）
    trap 'stop_spinner; rm -f "$temp_file"' INT TERM
    
    start_spinner "$message"
    
    # コマンドを実行し、出力を一時ファイルに保存
    local exit_code=0
    if ! "$@" >"$temp_file" 2>&1; then
        exit_code=$?
    fi
    
    stop_spinner
    
    if [[ $exit_code -eq 0 ]]; then
        show_success "完了"
        # 一時ファイルの内容を出力（改行を保持）
        cat "$temp_file"
        rm -f "$temp_file"
        trap - INT TERM
        return 0
    else
        # エラー時は内容を確認し、適切にハンドリング
        local content
        content=$(cat "$temp_file" 2>/dev/null || echo "")
        
        # ファイルサイズが大きい場合は先頭と末尾のみ表示
        local content_length=${#content}
        if [[ $content_length -gt 10000 ]]; then
            show_error "失敗（出力が大きいため先頭と末尾のみ表示）:"
            echo "=== 先頭1000文字 ===" >&2
            echo "${content:0:1000}" >&2
            echo "=== 末尾1000文字 ===" >&2
            echo "${content: -1000}" >&2
        elif [[ -n "$content" ]]; then
            show_error "失敗: $content"
        else
            show_error "失敗（出力なし）"
        fi
        
        rm -f "$temp_file"
        trap - INT TERM
        return $exit_code
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
            if ! read -p "$prompt [$default_value]: " -r input; then
                input="$default_value"
                echo >&2
            fi
            input="${input:-$default_value}"
        else
            if ! read -p "$prompt: " -r input; then
                input=""
                echo >&2
            fi
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