#!/bin/bash
# Gemini CLI統合スクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config_loader.sh"

# Gemini CLIが利用可能かチェック
check_gemini_cli() {
    log_debug "Gemini CLIの存在確認中..."
    
    if ! command -v gemini >/dev/null 2>&1; then
        log_error "Gemini CLIがインストールされていません"
        echo "エラー: Gemini CLIがインストールされていません" >&2
        echo "インストール方法:" >&2
        echo "  npm install -g @google/generative-ai-cli" >&2
        echo "または" >&2
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

# Gemini CLIを実行
call_gemini_cli() {
    local prompt="$1"
    local model="${2:-gemini-pro}"
    local temperature="${3:-0.3}"
    local max_tokens="${4:-100}"
    local timeout="${5:-30}"
    
    log_debug "Gemini CLI実行中（モデル: ${model}）..."
    
    # エラー出力を一時ファイルに保存
    local error_file=$(mktemp)
    
    # Gemini CLIを実行（このCLIは標準入力とプロンプトオプションをサポート）
    local result=""
    local exit_code=0
    
    # --promptオプションを使用（Docker環境での互換性のため）
    log_debug "--promptオプションでGemini CLI実行中..."
    
    # Gemini CLIを実行（ログ出力を完全に分離）
    # Docker環境では--promptオプションを使用（stdin使用でハングするため）
    local temp_output=$(mktemp)
    if (timeout "${timeout}" gemini --prompt="$prompt" 2>"$error_file") >"$temp_output"; then
        result=$(cat "$temp_output")
        rm -f "$temp_output"
        log_debug "成功: --promptオプション"
        log_debug "レスポンス長: ${#result} 文字"
    else
        exit_code=$?
        local error_output=$(cat "$error_file" 2>/dev/null || echo "")
        result=$(cat "$temp_output" 2>/dev/null || echo "")
        
        # タイムアウトでもレスポンスがある場合は成功とみなす
        if [[ $exit_code -eq 124 ]] && [[ -n "$result" ]] && [[ ${#result} -gt 10 ]]; then
            log_debug "タイムアウトだがレスポンス取得成功: ${#result} 文字"
            rm -f "$temp_output" "$error_file"
            echo "$result"
            return 0
        fi
        
        log_error "Gemini CLI実行が失敗"
        log_debug "終了コード: $exit_code"
        log_debug "エラー出力の長さ: ${#error_output} 文字"
        log_debug "エラー出力: $error_output"
        
        # APIキーの状態を確認
        if [[ -n "${GEMINI_API_KEY:-}" ]]; then
            log_debug "APIキー設定状況: 設定済み（長さ: ${#GEMINI_API_KEY} 文字）"
        else
            log_debug "APIキー設定状況: 未設定"
        fi
        
        # 実行環境の詳細をログ
        log_debug "実行環境: $0"
        log_debug "親プロセス: $(ps -o comm= -p $PPID 2>/dev/null || echo 'unknown')"
        log_debug "環境変数PATH: $PATH"
        log_debug "Gemini CLIパス: $(which gemini 2>/dev/null || echo 'not found')"
        
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
                if echo "$error_output" | grep -i "api.*key\|credentials\|auth" >/dev/null; then
                    log_error "APIキーエラー"
                    echo "エラー: APIキーが設定されていないか無効です" >&2
                    echo "現在のAPIキー設定: ${GEMINI_API_KEY:+設定済み}" >&2
                    echo "設定方法: export GEMINI_API_KEY=\"your-api-key\"" >&2
                elif echo "$error_output" | grep -i "rate.*limit\|quota\|limit.*exceeded" >/dev/null; then
                    log_error "レート制限エラー"
                    echo "エラー: APIレート制限に達しました" >&2
                    echo "しばらく待ってから再試行してください" >&2
                elif echo "$error_output" | grep -i "model.*not.*found\|invalid.*model" >/dev/null; then
                    log_error "モデルエラー"
                    echo "エラー: 指定されたモデル（$model）が利用できません" >&2
                    echo "利用可能なモデルを確認してください" >&2
                else
                    log_error "Gemini CLI実行エラー"
                    echo "エラー: Gemini CLIの実行に失敗しました" >&2
                    echo "実行環境: Docker コンテナ内" >&2
                    echo "デバッグのため以下を実行してください:" >&2
                    echo "  ./scripts/debug_gemini.sh" >&2
                    if [[ -n "$error_output" ]]; then
                        echo "詳細: $error_output" >&2
                    fi
                fi
                ;;
            127)
                log_error "コマンドが見つかりません"
                echo "エラー: Gemini CLIコマンドが見つかりません" >&2
                ;;
            *)
                log_error "予期しないエラー（終了コード: ${exit_code}）"
                echo "エラー: 予期しないエラーが発生しました" >&2
                if [[ -n "$error_output" ]]; then
                    echo "詳細: $error_output" >&2
                fi
                ;;
        esac
        
        # 一時ファイルをクリーンアップ
        rm -f "$temp_output" "$error_file"
        return $exit_code
    fi
    
    # 一時ファイルをクリーンアップ
    rm -f "$temp_output" "$error_file"
    
    # 結果を出力
    echo "$result"
    return 0
}

# レスポンスを後処理
process_response() {
    local response="$1"
    local max_length="${2:-72}"
    
    log_debug "レスポンス後処理中..."
    log_debug "元のレスポンス長: ${#response} 文字"
    
    # 不要な行を除去して最初の有効な行を取得
    response=$(echo "$response" | grep -v "Loaded cached credentials" | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # 文字数制限を適用
    if [[ ${#response} -gt $max_length ]]; then
        response="${response:0:$max_length}"
        log_warn "メッセージが最大長を超えたため切り詰められました"
    fi
    
    log_debug "処理後のメッセージ: $response"
    echo "$response"
}

# メイン実行関数
generate_commit_message() {
    local diff_content="$1"
    local file_analysis="$2"
    
    log_info "Gemini CLIを使用してコミットメッセージを生成中..."
    
    # 設定を読み込み
    local config=$(load_config)
    local model=$(echo "$config" | jq -r '.gemini.model // "gemini-pro"')
    local temperature=$(echo "$config" | jq -r '.gemini.temperature // 0.3')
    local max_tokens=$(echo "$config" | jq -r '.gemini.max_tokens // 100')
    local timeout=$(echo "$config" | jq -r '.gemini.timeout // 30')
    local language=$(echo "$config" | jq -r '.commit_message.language // "ja"')
    local max_length=$(echo "$config" | jq -r '.commit_message.max_length // 72')
    
    # Gemini CLIチェック
    if ! check_gemini_cli; then
        return 1
    fi
    
    # プロンプト生成
    local prompt=$(generate_prompt "$diff_content" "$file_analysis" "$language")
    
    # Gemini CLI実行
    local response
    response=$(call_gemini_cli "$prompt" "$model" "$temperature" "$max_tokens" "$timeout")
    
    if [[ $? -ne 0 ]]; then
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