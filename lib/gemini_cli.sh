#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

generate_prompt() {
    local diff_file="$1"
    local output_file="$2"
    local language="${3:-$COMMIT_LANGUAGE}"
    local format="${4:-$COMMIT_FORMAT}"
    
    log_debug "プロンプト生成を開始します (言語: $language, 形式: $format)"
    
    local diff_content
    if [ ! -f "$diff_file" ] || [ ! -r "$diff_file" ]; then
        show_error "差分ファイルが読み取れません: $diff_file"
        return $ERROR_GENERAL
    fi
    
    diff_content=$(cat "$diff_file")
    
    if [ -z "$diff_content" ]; then
        show_error "差分ファイルが空です"
        return $ERROR_GENERAL
    fi
    
    local system_prompt="あなたは経験豊富なソフトウェア開発者です。Git差分を分析して適切なコミットメッセージを生成してください。"
    
    local user_prompt
    case "$format" in
        "conventional")
            user_prompt="以下のgit diffを正確に分析して、適切なコミットメッセージを${language}で生成してください。

STRICT REQUIREMENTS (必ず従うこと):
1. 形式: [type]: [description] (例: feat: 新しい機能を追加)
2. type選択: feat(新機能), fix(修正), docs(文書), style(書式), refactor(リファクタ), test(テスト), chore(雑務)
3. 最大50文字以内
4. 一行で完結
5. 差分の内容のみを説明する

分析する差分:
${diff_content}

上記の差分を分析して、適切なコミットメッセージを一行で生成してください:"
            ;;
        "simple")
            user_prompt="以下の変更に対するコミットメッセージを${language}で生成してください。

要件:
- 50文字以内の簡潔な説明
- 変更の内容を明確に表現
- 一行で完結させる

変更内容:
${diff_content}

コミットメッセージ:"
            ;;
        *)
            user_prompt="以下の変更に対するコミットメッセージを${language}で生成してください。

変更内容:
${diff_content}

コミットメッセージ:"
            ;;
    esac
    
    cat > "$output_file" <<EOF
$system_prompt

$user_prompt
EOF
    
    # デバッグモードでプロンプトをログ出力
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "=== 生成されたプロンプト内容 ===" >&2
        cat "$output_file" >&2
        echo "=== プロンプト終了 ===" >&2
    fi
    
    log_debug "プロンプト生成完了 (サイズ: $(wc -c < "$output_file") bytes)"
    return $ERROR_SUCCESS
}

call_gemini_cli() {
    local prompt_file="$1"
    local output_file="$2"
    local model="${3:-$GEMINI_MODEL}"
    local temperature="${4:-$GEMINI_TEMPERATURE}"
    local max_tokens="${5:-$GEMINI_MAX_TOKENS}"
    local timeout="${6:-$GEMINI_TIMEOUT}"
    local max_retries=3
    local retry_count=0
    
    log_debug "GeminiCLI呼び出しを開始します (モデル: $model, 温度: $temperature, 最大トークン: $max_tokens)"
    
    if [ ! -f "$prompt_file" ] || [ ! -r "$prompt_file" ]; then
        show_error "プロンプトファイルが読み取れません: $prompt_file"
        return $ERROR_GENERAL
    fi
    
    show_info "AIがコミットメッセージを生成しています..."
    
    while [ $retry_count -lt $max_retries ]; do
        log_debug "GeminiCLI呼び出し試行 $((retry_count + 1))/$max_retries"
        
        local temp_error
        temp_error=$(create_secure_temp_file)
        
        if timeout "$timeout" gemini \
            --model "$model" \
            --prompt "$(cat "$prompt_file")" \
            > "$output_file" 2>"$temp_error"; then
            
            if [ -s "$output_file" ]; then
                log_debug "GeminiCLI呼び出し成功"
                rm -f "$temp_error"
                return $ERROR_SUCCESS
            else
                show_warning "GeminiCLIからの応答が空です"
            fi
        else
            local error_msg
            error_msg=$(cat "$temp_error" 2>/dev/null || echo "不明なエラー")
            show_warning "GeminiCLI呼び出し失敗: $error_msg"
        fi
        
        rm -f "$temp_error"
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $max_retries ]; then
            show_info "リトライします... (試行 $((retry_count + 1))/$max_retries)"
            sleep 2
        fi
    done
    
    show_error "GeminiCLI呼び出しに失敗しました (最大試行回数に達しました)"
    return $ERROR_GEMINI_API
}

validate_commit_message() {
    local message_file="$1"
    
    log_debug "コミットメッセージの検証を開始します"
    
    if [ ! -f "$message_file" ] || [ ! -r "$message_file" ]; then
        show_error "コミットメッセージファイルが読み取れません"
        return $ERROR_GENERAL
    fi
    
    local message
    message=$(cat "$message_file" | tr -d '\0' | head -1)
    
    if [ -z "$(echo "$message" | tr -d '[:space:]')" ]; then
        show_warning "生成されたコミットメッセージが空です"
        return $ERROR_GENERAL
    fi
    
    local message_length
    message_length=${#message}
    
    if [ "$message_length" -gt 100 ]; then
        show_warning "コミットメッセージが長すぎます ($message_length 文字 > 100 文字)"
        show_info "メッセージを短縮することを推奨します"
    fi
    
    log_debug "コミットメッセージ検証完了 (長さ: $message_length 文字)"
    return $ERROR_SUCCESS
}

sanitize_commit_message() {
    local input_file="$1"
    local output_file="$2"
    
    log_debug "コミットメッセージのサニタイゼーションを開始します"
    
    local message
    message=$(cat "$input_file")
    
    message=$(echo "$message" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    message=$(echo "$message" | grep -v '^#' | head -1)
    
    message=$(echo "$message" | tr -d '\0\r')
    
    echo "$message" > "$output_file"
    
    log_debug "コミットメッセージのサニタイゼーション完了"
    return $ERROR_SUCCESS
}