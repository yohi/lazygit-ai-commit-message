#!/bin/bash
# Gemini CLI統合スクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config_loader.sh"

# timeoutコマンドの可用性チェック
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
else
    log_warn "timeout または gtimeout コマンドが見つかりません"
    echo "警告: timeout コマンドが利用できません。タイムアウトなしで続行します。" >&2
    echo "改善方法: brew install coreutils" >&2
fi

# Gemini CLIが利用可能かチェック
check_gemini_cli() {
    log_debug "Gemini CLIの存在確認中..."
    
    local gemini_cmd
    gemini_cmd="$(get_gemini_command)"
    
    if ! command -v "$gemini_cmd" >/dev/null 2>&1; then
        log_error "Gemini CLIがインストールされていません"
        echo "エラー: ${gemini_cmd}がインストールされていません" >&2
        echo "推奨インストール方法（Node.js環境）:" >&2
        echo "  npm install -g @google/generative-ai-cli" >&2
        echo "代替方法（Python環境）:" >&2
        echo "  pip install google-generativeai-cli" >&2
        return 1
    fi
    
    log_info "Gemini CLIが利用可能です"
    return 0
}

# プロンプトテンプレートを生成
generate_prompt() {
    local diff_content="$1"
    local file_analysis="$2"
    local language="${3:-ja}"
    
    log_debug "プロンプト生成中（言語: ${language}）..."
    
    if [[ "$language" == "en" ]]; then
        cat <<EOF
Analyze the following git diff and generate an appropriate commit message.

Requirements:
- Concise summary line within 50 characters
- Use conventional commit format when appropriate
- Write in English
- Capture the essence of the changes

Git Diff:
${diff_content}

File Information:
${file_analysis}

Generate a commit message:
EOF
    else
        cat <<EOF
以下の変更をコミットメッセージにしてください。50文字以内、日本語。

変更内容:
${file_analysis}

Git Diff:
${diff_content}
EOF
    fi
}

# Gemini CLIの実際のコマンドを確認
get_gemini_command() {
    # このGemini CLIは標準入力とプロンプトオプションをサポート
    echo "gemini"
}

# Geminiエラーハンドリング関数
handle_gemini_error() {
    local exit_code="$1"
    local error_output="$2"
    local result="$3"
    local timeout="$4"
    local prompt="$5"
    
    # タイムアウトでもレスポンスがある場合は成功とみなす
    if [[ $exit_code -eq 124 ]] && [[ -n "$result" ]] && [[ ${#result} -gt 10 ]]; then
        log_debug "タイムアウトだがレスポンス取得成功: ${#result} 文字"
        echo "$result"
        return 0
    fi
    
    log_error "Gemini CLI実行が失敗"
    log_debug "終了コード: $exit_code"
    log_debug "エラー出力の長さ: ${#error_output} 文字"
    log_debug "エラー出力: $error_output"
    
    # APIキーの状態を確認
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        log_debug "APIキー設定状況: 設定済み"
    else
        log_debug "APIキー設定状況: 未設定"
    fi
    
    # 実行環境の詳細をログ
    log_debug "実行環境: $0"
    log_debug "親プロセス: $(ps -o comm= -p $PPID 2>/dev/null || echo 'unknown')"
    log_debug "環境変数PATH: $PATH"
    log_debug "Gemini CLIパス: $(command -v "$(get_gemini_command)" 2>/dev/null || echo 'not found')"
    
    # プロンプトの詳細をログ
    log_debug "プロンプト長: ${#prompt} 文字"
    log_debug "プロンプト先頭50文字: ${prompt:0:50}..."
    
    # エラー詳細を分析
    case $exit_code in
        124)
            log_error "Gemini API呼び出しがタイムアウトしました"
            echo "エラー: APIリクエストがタイムアウトしました（${timeout}秒）" >&2
            ;;
        1)
            log_error "Gemini CLI実行エラー"
            echo "エラー: Gemini CLI実行に失敗しました" >&2
            echo "詳細: $error_output" >&2
            ;;
        127)
            log_error "Gemini CLIが見つかりません"
            echo "エラー: $(get_gemini_command)コマンドが見つかりません" >&2
            ;;
        *)
            log_error "予期しないエラー（終了コード: $exit_code）"
            echo "エラー: 予期しないエラーが発生しました" >&2
            echo "終了コード: $exit_code" >&2
            echo "詳細: $error_output" >&2
            ;;
    esac
    
    return 1
}

# Gemini CLIを実行
call_gemini_cli() {
    local prompt="$1"
    local model="${2:-gemini-pro}"
    local temperature="${3:-0.3}"
    local max_tokens="${4:-100}"
    local timeout="${5:-30}"
    
    log_info "Gemini CLI実行中（モデル: ${model}）..."
    log_info "プロンプト内容をログに記録中..."
    log_debug "プロンプト詳細: ${prompt}"
    
    # エラー出力を一時ファイルに保存
    local error_file
    error_file=$(mktemp)
    if [[ ! -f "$error_file" ]]; then
        log_error "mktempで一時ファイルの作成に失敗しました"
        return 1
    fi
    
    # Gemini CLIを実行（このCLIは標準入力とプロンプトオプションをサポート）
    local result=""
    local exit_code=0
    
    # --promptオプションを使用（Docker環境での互換性のため）
    log_debug "--promptオプションでGemini CLI実行中..."
    
    # Gemini CLIを実行（ログ出力を完全に分離）
    # Docker環境では--promptオプションを使用（stdin使用でハングするため）
    local temp_output
    temp_output=$(mktemp)
    if [[ ! -f "$temp_output" ]]; then
        log_error "mktempで一時ファイルの作成に失敗しました"
        rm -f "$error_file"
        return 1
    fi
    if [[ -n "$TIMEOUT_CMD" ]]; then
        log_info "Gemini APIリクエスト送信中..."
        if ("$TIMEOUT_CMD" "${timeout}" "$(get_gemini_command)" --prompt="$prompt" 2>"$error_file") >"$temp_output"; then
            result=$(cat "$temp_output")
            rm -f "$temp_output" "$error_file"
            log_info "Gemini APIレスポンス受信成功（timeoutあり）"
            log_info "レスポンス長: ${#result} 文字"
            log_debug "生成されたコミットメッセージ: ${result}"
        else
            exit_code=$?
            local error_output=""
            error_output=$(cat "$error_file" 2>/dev/null || echo "")
            result=$(cat "$temp_output" 2>/dev/null || echo "")
            rm -f "$temp_output" "$error_file"
            if handle_gemini_error "$exit_code" "$error_output" "$result" "$timeout" "$prompt"; then
                return 0
            else
                return $exit_code
            fi
        fi
    else
        # timeout コマンドが利用できない場合のfallback
        log_info "timeoutコマンドが利用できないため、通常実行します"
        log_info "Gemini APIリクエスト送信中..."
        if ("$(get_gemini_command)" --prompt="$prompt" 2>"$error_file") >"$temp_output"; then
            result=$(cat "$temp_output")
            rm -f "$temp_output" "$error_file"
            log_info "Gemini APIレスポンス受信成功（timeoutなし）"
            log_info "レスポンス長: ${#result} 文字"
            log_debug "生成されたコミットメッセージ: ${result}"
        else
            exit_code=$?
            local error_output=""
            error_output=$(cat "$error_file" 2>/dev/null || echo "")
            result=$(cat "$temp_output" 2>/dev/null || echo "")
            rm -f "$temp_output" "$error_file"
            if handle_gemini_error "$exit_code" "$error_output" "$result" "$timeout" "$prompt"; then
                return 0
            else
                return $exit_code
            fi
        fi
    fi
    
    # 結果を出力
    echo "$result"
    return 0
}

# レスポンスを後処理
process_response() {
    local response="$1"
    local max_length="${2:-72}"
    
    log_info "レスポンス後処理中..."
    log_info "元のレスポンス長: ${#response} 文字"
    log_debug "元のレスポンス内容: ${response}"
    
    # 不要な行を除去して最初の有効な行を取得
    # ログ行やキャッシュメッセージを除外
    response=$(echo "$response" | grep -v "Loaded cached credentials" | grep -v "^\[.*\] \[.*\]" | grep -v "^INFO\|^DEBUG\|^WARN\|^ERROR" | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # 文字数制限を適用
    if [[ ${#response} -gt $max_length ]]; then
        response="${response:0:$max_length}"
        log_warn "メッセージが最大長（${max_length}文字）を超えたため切り詰められました"
        log_info "切り詰め後の長さ: ${#response} 文字"
    fi
    
    log_info "処理後のメッセージ: ${response}"
    echo "$response"
}

# メイン実行関数
generate_commit_message() {
    local diff_content="$1"
    local file_analysis="$2"
    
    log_info "Gemini CLIを使用してコミットメッセージを生成中..."
    
    # 設定を読み込み
    local config=""
    config=$(load_config)
    local model temperature max_tokens timeout language max_length
    
    if command -v jq >/dev/null 2>&1; then
        model=$(echo "$config" | jq -r '.gemini.model // "gemini-pro"')
        temperature=$(echo "$config" | jq -r '.gemini.temperature // 0.3')
        max_tokens=$(echo "$config" | jq -r '.gemini.max_tokens // 100')
        timeout=$(echo "$config" | jq -r '.gemini.timeout // 30')
        language=$(echo "$config" | jq -r '.commit_message.language // "ja"')
        max_length=$(echo "$config" | jq -r '.commit_message.max_length // 50')
    else
        # jqが使用できない場合のデフォルト値
        model="gemini-pro"
        temperature="0.3"
        max_tokens="100"
        timeout="30"
        language="ja"
        max_length="50"
    fi
    
    # Gemini CLIチェック
    if ! check_gemini_cli; then
        return 1
    fi
    
    # プロンプト生成
    local prompt
    prompt="$(generate_prompt "$diff_content" "$file_analysis" "$language")"
    
    # Gemini CLI実行
    local response
    if ! response="$(call_gemini_cli "$prompt" "$model" "$temperature" "$max_tokens" "$timeout")"; then
        return 1
    fi
    
    # レスポンス後処理
    local processed_message
    processed_message=$(process_response "$response" "$max_length")
    
    echo "$processed_message"
    log_info "コミットメッセージ生成完了"
    return 0
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "使用方法: $0 <diff_content> <file_analysis>" >&2
        exit 1
    fi
    
    generate_commit_message "$1" "$2"
fi