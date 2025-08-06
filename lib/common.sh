#!/bin/bash

# エラーコードの定義（重複定義を防ぐ）
if [[ -z "${ERROR_SUCCESS:-}" ]]; then
    readonly ERROR_SUCCESS=0
    readonly ERROR_GENERAL=1
    readonly ERROR_CONFIG=2
    readonly ERROR_DEPENDENCY=3
    readonly ERROR_NO_STAGED_FILES=4
    readonly ERROR_GEMINI_API=5
    readonly ERROR_USER_CANCEL=6
fi

show_error() {
    echo "❌ エラー: $1" >&2
}

show_warning() {
    echo "⚠️  警告: $1" >&2
}

show_info() {
    echo "ℹ️  情報: $1" >&2
}

show_success() {
    echo "✅ 成功: $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "🐛 デバッグ: $1" >&2
    fi
}

log_error_with_exit() {
    local exit_code=$1
    local message="$2"
    echo "❌ エラー (exit $exit_code): $message" >&2
    
    # Lazygit用のログファイルにも出力
    local log_file="/tmp/lazygit-gemini-commit.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] exit_code=$exit_code: $message" >> "$log_file"
    
    return $exit_code
}

log_to_file() {
    local level="$1"
    local message="$2"
    local log_file="/tmp/lazygit-gemini-commit.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$log_file"
}

create_secure_temp_file() {
    local temp_file
    temp_file=$(mktemp)
    chmod 600 "$temp_file"
    echo "$temp_file"
}

is_git_repository() {
    git rev-parse --git-dir >/dev/null 2>&1
}

get_git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}