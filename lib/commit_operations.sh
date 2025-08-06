#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

open_commit_editor() {
    local message_file="$1"
    local editor_command="${2:-${EDITOR:-vim}}"
    
    log_debug "コミットエディタ起動を開始します (エディタ: $editor_command)"
    
    if [ ! -f "$message_file" ] || [ ! -r "$message_file" ]; then
        show_error "コミットメッセージファイルが読み取れません: $message_file"
        return $ERROR_GENERAL
    fi
    
    local commit_message
    commit_message=$(cat "$message_file")
    
    if [ -z "$(echo "$commit_message" | tr -d '[:space:]')" ]; then
        show_warning "生成されたコミットメッセージが空です"
        show_info "空のエディタでコミットプロセスを継続します"
        commit_message=""
    fi
    
    show_info "コミットエディタを起動します..."
    show_info "生成されたメッセージを確認・編集してください"
    
    if ! git commit --edit --message="$commit_message"; then
        local exit_code=$?
        case $exit_code in
            1)
                show_warning "コミットがユーザーによってキャンセルされました"
                return $ERROR_USER_CANCEL
                ;;
            128)
                show_error "Gitリポジトリまたは設定に問題があります"
                return $ERROR_GENERAL
                ;;
            *)
                show_error "コミットエディタの実行に失敗しました (終了コード: $exit_code)"
                return $ERROR_GENERAL
                ;;
        esac
    fi
    
    show_success "コミットが完了しました"
    return $ERROR_SUCCESS
}

commit_with_message() {
    local message_file="$1"
    local auto_commit="${2:-false}"
    
    log_debug "コミット実行を開始します (自動コミット: $auto_commit)"
    
    if [ ! -f "$message_file" ] || [ ! -r "$message_file" ]; then
        show_error "コミットメッセージファイルが読み取れません: $message_file"
        return $ERROR_GENERAL
    fi
    
    local commit_message
    commit_message=$(cat "$message_file" | head -1 | tr -d '\0\r')
    
    if [ -z "$(echo "$commit_message" | tr -d '[:space:]')" ]; then
        show_error "コミットメッセージが空です"
        return $ERROR_GENERAL
    fi
    
    if [ "$auto_commit" = "true" ]; then
        show_info "自動コミットを実行します..."
        show_info "メッセージ: $commit_message"
        
        if ! git commit --message="$commit_message"; then
            show_error "自動コミットに失敗しました"
            return $ERROR_GENERAL
        fi
        
        show_success "自動コミットが完了しました"
    else
        open_commit_editor "$message_file"
        return $?
    fi
    
    return $ERROR_SUCCESS
}

show_commit_preview() {
    local message_file="$1"
    
    log_debug "コミットプレビューを表示します"
    
    if [ ! -f "$message_file" ] || [ ! -r "$message_file" ]; then
        show_error "コミットメッセージファイルが読み取れません: $message_file"
        return $ERROR_GENERAL
    fi
    
    local commit_message
    commit_message=$(cat "$message_file")
    
    echo ""
    echo "========================================="
    echo "生成されたコミットメッセージ:"
    echo "========================================="
    echo "$commit_message"
    echo "========================================="
    echo ""
    
    local stats
    if stats=$(get_staged_summary 2>/dev/null); then
        echo "変更統計:"
        echo "$stats"
        echo ""
    fi
    
    return $ERROR_SUCCESS
}

confirm_commit() {
    local message="コミットを実行しますか？"
    
    echo -n "$message [Y/n]: "
    read -r response
    
    case "$response" in
        [nN]|[nN][oO])
            return $ERROR_USER_CANCEL
            ;;
        *)
            return $ERROR_SUCCESS
            ;;
    esac
}