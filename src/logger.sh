#!/bin/bash
# ログ機能

# ログレベル
LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_FILE="${LOG_FILE:-}"

# ログレベル定義
declare -A LOG_LEVELS=(
    ["debug"]=0
    ["info"]=1
    ["warn"]=2
    ["error"]=3
)

# 現在のログレベルを数値で取得
get_log_level_num() {
    echo "${LOG_LEVELS[${LOG_LEVEL}]:-1}"
}

# ログ出力関数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    local current_level
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ログレベルチェック
    current_level=$(get_log_level_num)
    local msg_level="${LOG_LEVELS[${level}]:-1}"
    
    if [[ $msg_level -lt $current_level ]]; then
        return 0
    fi
    
    # ログメッセージ形式
    local log_line="[${timestamp}] [${level^^}] ${message}"
    
    # ファイル出力
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_line" >> "$LOG_FILE"
    fi
    
    # コンソール出力（エラーの場合は stderr）
    if [[ "$level" == "error" ]]; then
        echo "$log_line" >&2
    else
        echo "$log_line"
    fi
}

# ログレベル別関数
log_debug() {
    log_message "debug" "$1"
}

log_info() {
    log_message "info" "$1"
}

log_warn() {
    log_message "warn" "$1"
}

log_error() {
    log_message "error" "$1"
}