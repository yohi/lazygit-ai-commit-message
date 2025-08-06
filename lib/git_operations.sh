#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

validate_staged_files() {
    local staged_files
    
    log_debug "ステージングされたファイルの確認を開始します"
    
    if ! staged_files=$(git diff --cached --name-only 2>/dev/null); then
        show_error "Gitの状態取得に失敗しました"
        return $ERROR_GENERAL
    fi
    
    if [ -z "$staged_files" ]; then
        show_error "ステージングされたファイルがありません"
        show_info "最初にファイルをステージング (git add) してください"
        return $ERROR_NO_STAGED_FILES
    fi
    
    local file_count
    file_count=$(echo "$staged_files" | wc -l)
    
    log_debug "ステージングされたファイル数: $file_count"
    log_debug "ファイル一覧:"
    while IFS= read -r file; do
        log_debug "  - $file"
    done <<< "$staged_files"
    
    show_info "$file_count 個のファイルがステージングされています"
    return $ERROR_SUCCESS
}

get_staged_diff() {
    local output_file="$1"
    local max_size="${2:-$MAX_DIFF_SIZE}"
    
    log_debug "ステージングされた差分の取得を開始します (最大サイズ: $max_size bytes)"
    
    local raw_diff
    if ! raw_diff=$(git diff --cached 2>/dev/null); then
        show_error "Git差分の取得に失敗しました"
        return $ERROR_GENERAL
    fi
    
    if [ -z "$raw_diff" ]; then
        show_error "差分データが空です"
        return $ERROR_NO_STAGED_FILES
    fi
    
    local diff_size
    diff_size=$(echo "$raw_diff" | wc -c)
    
    if [ "$diff_size" -gt "$max_size" ]; then
        show_warning "差分データが大きすぎます (${diff_size} bytes > ${max_size} bytes)"
        show_info "差分データを切り詰めます"
        
        echo "$raw_diff" | head -c "$max_size" > "$output_file"
        echo -e "\n\n[... 差分データが切り詰められました ...]" >> "$output_file"
    else
        echo "$raw_diff" > "$output_file"
    fi
    
    log_debug "差分データを取得しました (サイズ: $diff_size bytes)"
    return $ERROR_SUCCESS
}

sanitize_diff_content() {
    local input_file="$1"
    local output_file="$2"
    
    log_debug "差分データのサニタイゼーションを開始します"
    
    sed \
        -e 's/password[[:space:]]*=[[:space:]]*[^[:space:]]*/password=***REDACTED***/gi' \
        -e 's/api[_-]key[[:space:]]*=[[:space:]]*[^[:space:]]*/api_key=***REDACTED***/gi' \
        -e 's/token[[:space:]]*=[[:space:]]*[^[:space:]]*/token=***REDACTED***/gi' \
        -e 's/secret[[:space:]]*=[[:space:]]*[^[:space:]]*/secret=***REDACTED***/gi' \
        -e 's/\(key\|pwd\|pass\)[[:space:]]*[:=][[:space:]]*['\''"][^'\''"]*['\''"]/(key_or_password)=***REDACTED***/gi' \
        "$input_file" > "$output_file"
    
    log_debug "差分データのサニタイゼーション完了"
    return $ERROR_SUCCESS
}

get_staged_summary() {
    local stats
    
    if ! stats=$(git diff --cached --stat 2>/dev/null); then
        show_error "Git統計情報の取得に失敗しました"
        return $ERROR_GENERAL
    fi
    
    echo "$stats"
    return $ERROR_SUCCESS
}