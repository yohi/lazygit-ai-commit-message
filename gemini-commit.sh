#!/bin/bash

set -euo pipefail

# 引数をチェックしてメッセージ表示モードかどうか判定
SHOW_MESSAGE_MODE=false
for arg in "$@"; do
    if [[ "$arg" == "--show-message" ]]; then
        SHOW_MESSAGE_MODE=true
        break
    fi
done

# Lazygitからの実行時のエラーをキャッチ（メッセージ表示モード以外）
if [[ "${LAZYGIT:-}" == "1" ]] && [[ "$SHOW_MESSAGE_MODE" != "true" ]]; then
    exec >> "/tmp/lazygit-gemini-commit.log" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] スクリプト開始 (bash version: $BASH_VERSION)"
fi

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/dependencies.sh"
source "$SCRIPT_DIR/lib/git_operations.sh"
source "$SCRIPT_DIR/lib/gemini_cli.sh"
source "$SCRIPT_DIR/lib/commit_operations.sh"

TEMP_FILES=()

cleanup() {
    local exit_code=$?
    if [[ "${LAZYGIT:-}" == "1" ]] && [[ $exit_code -ne 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] スクリプト異常終了 (exit code: $exit_code)" >> "/tmp/lazygit-gemini-commit.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 実行中のファンクション: ${FUNCNAME[*]}" >> "/tmp/lazygit-gemini-commit.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 実行中の行番号: ${BASH_LINENO[*]}" >> "/tmp/lazygit-gemini-commit.log"
    fi
    for temp_file in "${TEMP_FILES[@]}"; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
    exit $exit_code
}

trap cleanup EXIT

create_temp_file() {
    local temp_file
    temp_file=$(create_secure_temp_file)
    TEMP_FILES+=("$temp_file")
    echo "$temp_file"
}

show_usage() {
    cat << EOF
使用方法: $SCRIPT_NAME [オプション]

LazygitでGeminiCLIを使用してAI駆動のコミットメッセージを生成します。

オプション:
    -h, --help          このヘルプを表示
    -v, --version       バージョン情報を表示
    -c, --config        現在の設定を表示
    --create-config     デフォルト設定ファイルを作成
    --check-deps        依存関係をチェック
    --debug             デバッグモードで実行

例:
    $SCRIPT_NAME                    通常の実行
    $SCRIPT_NAME --check-deps       依存関係チェックのみ実行
    $SCRIPT_NAME --create-config    設定ファイル作成
    DEBUG=1 $SCRIPT_NAME            デバッグモードで実行

詳細については、README.md を参照してください。
EOF
}

show_version() {
    echo "Lazygit GeminiCLI Commit Plugin v1.0.0"
    echo "Copyright (c) 2024"
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                return $ERROR_SUCCESS
                ;;
            -v|--version)
                show_version
                return $ERROR_SUCCESS
                ;;
            -c|--config)
                load_config
                show_config
                return $ERROR_SUCCESS
                ;;
            --create-config)
                create_default_config
                return $?
                ;;
            --check-deps)
                check_dependencies
                return $?
                ;;
            --debug)
                export DEBUG=1
                ;;
            --no-interaction)
                export NO_INTERACTION=1
                ;;
            --show-message)
                export SHOW_MESSAGE_ONLY=1
                export NO_INTERACTION=1
                ;;
            *)
                show_error "不明なオプション: $1"
                show_usage
                return $ERROR_GENERAL
                ;;
        esac
        shift
    done
    
    # Lazygit環境では対話を無効化
    if [[ "${LAZYGIT:-}" == "1" ]] || [[ "${NO_INTERACTION:-}" == "1" ]]; then
        export SHOW_PROGRESS=false
        export CONFIRM_BEFORE_COMMIT=false
        export AUTO_COMMIT=true
    fi
    
    log_debug "Lazygit GeminiCLI コミットメッセージ生成を開始します..."
    
    log_to_file "INFO" "プラグイン実行開始 (PID=$$, PWD=$PWD, LAZYGIT=${LAZYGIT:-0})"
    
    load_config || {
        log_error_with_exit $ERROR_CONFIG "設定の読み込みに失敗しました"
        return $ERROR_CONFIG
    }
    log_to_file "INFO" "設定読み込み完了"
    
    check_dependencies || {
        log_error_with_exit $ERROR_DEPENDENCY "依存関係チェックに失敗しました"
        return $ERROR_DEPENDENCY
    }
    log_to_file "INFO" "依存関係チェック完了"
    
    check_git_repository || {
        log_error_with_exit $ERROR_GENERAL "Gitリポジトリではありません"
        return $ERROR_GENERAL
    }
    log_to_file "INFO" "Gitリポジトリ確認完了"
    
    validate_staged_files || {
        log_error_with_exit $ERROR_NO_STAGED_FILES "ステージングファイルの検証に失敗しました"
        return $ERROR_NO_STAGED_FILES
    }
    log_to_file "INFO" "ステージングファイル確認完了"
    
    local diff_file prompt_file message_file sanitized_diff_file
    diff_file=$(create_temp_file)
    sanitized_diff_file=$(create_temp_file)
    prompt_file=$(create_temp_file)
    message_file=$(create_temp_file)
    
    get_staged_diff "$diff_file" || {
        log_error_with_exit $ERROR_GENERAL "差分の取得に失敗しました"
        return $ERROR_GENERAL
    }
    log_to_file "INFO" "差分取得完了"
    
    sanitize_diff_content "$diff_file" "$sanitized_diff_file" || {
        log_error_with_exit $ERROR_GENERAL "差分のサニタイゼーションに失敗しました"
        return $ERROR_GENERAL
    }
    log_to_file "INFO" "差分サニタイゼーション完了"
    
    generate_prompt "$sanitized_diff_file" "$prompt_file" "$COMMIT_LANGUAGE" "$COMMIT_FORMAT" || {
        log_error_with_exit $ERROR_GENERAL "プロンプトの生成に失敗しました"
        return $ERROR_GENERAL
    }
    log_to_file "INFO" "プロンプト生成完了"
    
    call_gemini_cli "$prompt_file" "$message_file" "$GEMINI_MODEL" "$GEMINI_TEMPERATURE" "$GEMINI_MAX_TOKENS" "$GEMINI_TIMEOUT" || {
        log_error_with_exit $ERROR_GEMINI_API "GeminiCLIの呼び出しに失敗しました"
        return $ERROR_GEMINI_API
    }
    log_to_file "INFO" "GeminiCLI呼び出し完了"
    
    local sanitized_message_file
    sanitized_message_file=$(create_temp_file)
    
    sanitize_commit_message "$message_file" "$sanitized_message_file" || {
        log_error_with_exit $ERROR_GENERAL "コミットメッセージのサニタイゼーションに失敗しました"
        return $ERROR_GENERAL
    }
    log_to_file "INFO" "メッセージサニタイゼーション完了"
    
    validate_commit_message "$sanitized_message_file" || {
        show_warning "生成されたコミットメッセージに問題がありますが続行します"
        log_to_file "WARN" "コミットメッセージ検証で警告あり"
    }
    
    if [ "$SHOW_PROGRESS" = "true" ]; then
        show_commit_preview "$sanitized_message_file"
    fi
    log_to_file "INFO" "プレビュー表示完了"
    
    # メッセージ表示モード（Lazygitプロンプト用）
    if [[ "${SHOW_MESSAGE_ONLY:-}" == "1" ]]; then
        local generated_message
        generated_message=$(head -1 "$sanitized_message_file")
        echo "$generated_message"
        return $ERROR_SUCCESS
    fi
    
    if [ "$CONFIRM_BEFORE_COMMIT" = "true" ]; then
        log_to_file "INFO" "ユーザー確認待ち"
        confirm_commit || {
            show_info "コミットがキャンセルされました"
            log_to_file "INFO" "ユーザーによりキャンセル"
            return $ERROR_USER_CANCEL
        }
    fi
    
    log_to_file "INFO" "コミット実行開始"
    commit_with_message "$sanitized_message_file" "$AUTO_COMMIT" || {
        log_error_with_exit $ERROR_GENERAL "コミットに失敗しました"
        return $ERROR_GENERAL
    }
    
    show_success "AIによるコミットメッセージ生成が完了しました"
    log_to_file "INFO" "プラグイン実行完了 (成功)"
    
    # Lazygitでのプロセス終了を明示的に示す
    if [[ "${LAZYGIT:-}" == "1" ]]; then
        echo "Plugin execution completed successfully" >&2
        exit 0
    fi
    
    return $ERROR_SUCCESS
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi