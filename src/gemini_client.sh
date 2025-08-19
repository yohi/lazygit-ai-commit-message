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
以下のGit変更を分析して、適切なコミットメッセージを1行で生成してください。

要求事項:
- 50文字以内の日本語で記述
- 「追加」「更新」「削除」「修正」などの動詞を使用
- 説明文や挨拶は不要、コミットメッセージのみを出力
- 例: "ユーザー認証機能を追加", "設定ファイルを更新"

変更内容:
${file_analysis}

Git Diff:
${diff_content}

コミットメッセージ:
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
    
    # Gemini CLIを実行
    local result=""
    local exit_code=0
    
    log_debug "Gemini CLI実行中（タイムアウト: ${timeout}秒）..."
    
    # 一時ファイルを作成
    local temp_output
    temp_output=$(mktemp)
    if [[ ! -f "$temp_output" ]]; then
        log_error "mktempで一時ファイルの作成に失敗しました"
        rm -f "$error_file"
        return 1
    fi
    
    # Gemini CLIを実行
    if [[ -n "$TIMEOUT_CMD" ]]; then
        log_info "Gemini APIリクエスト送信中 (タイムアウト: ${timeout}秒)..."
        if "$TIMEOUT_CMD" "${timeout}" "$(get_gemini_command)" --prompt="$prompt" >"$temp_output" 2>"$error_file"; then
            result=$(cat "$temp_output" 2>/dev/null)
            exit_code=0
        else
            exit_code=$?
            result=$(cat "$temp_output" 2>/dev/null || echo "")
        fi
    else
        log_info "Gemini APIリクエスト送信中..."
        if "$(get_gemini_command)" --prompt="$prompt" >"$temp_output" 2>"$error_file"; then
            result=$(cat "$temp_output" 2>/dev/null)
            exit_code=0
        else
            exit_code=$?
            result=$(cat "$temp_output" 2>/dev/null || echo "")
        fi
    fi
    
    # 一時ファイルをクリーンアップ
    local error_output=""
    error_output=$(cat "$error_file" 2>/dev/null || echo "")
    rm -f "$temp_output" "$error_file"
    
    # 結果を確認
    if [[ $exit_code -eq 0 ]]; then
        log_info "Gemini APIレスポンス受信成功"
        log_info "レスポンス長: ${#result} 文字"
        log_debug "生成されたコミットメッセージ: ${result}"
    else
        if handle_gemini_error "$exit_code" "$error_output" "$result" "$timeout" "$prompt"; then
            return 0
        else
            return $exit_code
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
    local file_analysis="${3:-}"
    
    log_info "レスポンス後処理中..."
    log_info "元のレスポンス長: ${#response} 文字"
    log_debug "元のレスポンス内容: ${response}"
    
    # 不要な行を除去して実際のコミットメッセージを抽出
    # AI応答の冗長な表現と技術的な情報を除去
    response=$(echo "$response" | \
        grep -v "Loaded cached credentials" | \
        grep -v "Data collection is disabled" | \
        grep -v "^\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].*\]" | \
        grep -v "^\[INFO\]" | \
        grep -v "^\[DEBUG\]" | \
        grep -v "^\[WARN\]" | \
        grep -v "^\[ERROR\]" | \
        grep -v "Gemini CLI" | \
        grep -v "はい.*承知" | \
        grep -v "以下に.*提案" | \
        grep -v "コミットメッセージを.*提案" | \
        grep -v "適切なコミットメッセージ" | \
        grep -v "以下のようなコミットメッセージ" | \
        grep -v "プロンプト" | \
        grep -v "レスポンス" | \
        grep -v "実行中" | \
        grep -v "送信中" | \
        grep -v "受信" | \
        grep -v "処理中" | \
        grep -v "生成" | \
        grep -v "を使用して" | \
        grep -v "が利用可能" | \
        grep -v "元のレスポンス" | \
        grep -v "処理後のメッセージ" | \
        grep -v "完了" | \
        grep -v "フォールバック" | \
        grep -v "^$")
    
    # コミットメッセージらしい行を抽出（改善されたパターン）
    local clean_message=""
    while IFS= read -r line; do
        # 空行や不適切な行をスキップ
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # 明らかに不適切な行を除外
        if [[ "$line" =~ ^(はい|承知|以下|について|です|ます|すみません) ]] || \
           [[ "$line" =~ (してください|お願い|いかがでしょうか|どうでしょう) ]] || \
           [[ "$line" =~ ^[\*\-\+\.].*$ ]] || \
           [[ ${#line} -lt 5 ]] || \
           [[ ${#line} -gt 100 ]]; then
            continue
        fi
        
        # コミットメッセージらしい行をチェック（優先順位順）
        if [[ "$line" =~ ^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert) ]] || \
           [[ "$line" =~ ^(Add|Update|Delete|Remove|Fix|Create|Modify|Change) ]] || \
           [[ "$line" =~ ^(追加|更新|削除|変更|修正|作成|改善|実装) ]] || \
           [[ "$line" =~ ^[A-Z][a-z].*[^.:!?]$ ]] || \
           [[ "$line" =~ ファイル.*[追加更新削除変更] ]] || \
           [[ "$line" =~ [追加更新削除変更].*ファイル ]]; then
            clean_message="$line"
            break
        fi
    done <<< "$response"
    
    # まだ見つからない場合は最初の有効そうな行を使用（さらに改善）
    if [[ -z "$clean_message" ]]; then
        # 残っている行から不適切でない最初の行を取得
        while IFS= read -r line; do
            # 明らかに不適切な文章を避ける
            if [[ ! "$line" =~ ^(承知|了解|分かり|わかり|はい|です|ます) ]] && \
               [[ ! "$line" =~ (いたします|お手伝い|サポート|ヘルプ) ]] && \
               [[ ${#line} -ge 5 ]] && [[ ${#line} -le 72 ]]; then
                clean_message="$line"
                break
            fi
        done <<< "$response"
    fi
    
    # それでも見つからない場合は、汎用的なフォールバックを使用
    if [[ -z "$clean_message" ]]; then
        log_warn "有効なコミットメッセージが抽出できませんでした。空の応答として返します。"
        clean_message=""
    fi
    
    response="$clean_message"
    
    # 文字数制限を適用
    if [[ ${#response} -gt $max_length ]]; then
        response="${response:0:$max_length}"
        log_warn "メッセージが最大長（${max_length}文字）を超えたため切り詰められました"
        log_info "切り詰め後の長さ: ${#response} 文字"
    fi
    
    log_info "処理後のメッセージ: ${response}"
    log_debug "レスポンス長: ${#response}"
    log_debug "レスポンス内容チェック: '${response}'"
    
    # 最終的なレスポンスが空の場合、またはエラーメッセージのみの場合の処理
    if [[ -z "$response" ]] || [[ "$response" == "Data collection is disabled." ]] || [[ "$response" =~ ^Data\ collection\ is\ disabled\.* ]]; then
        log_warn "Gemini CLIから有効なレスポンスが得られませんでした - フォールバック機能を使用"
        
        # ファイル分析結果からシンプルなコミットメッセージを生成
        local fallback_message
        if [[ -n "${file_analysis:-}" ]]; then
            # ファイル分析結果からフォールバックメッセージを生成
            local file_count=$(echo "$file_analysis" | jq -r '.summary.total_files' 2>/dev/null || echo "1")
            local lines_added=$(echo "$file_analysis" | jq -r '.summary.lines_added' 2>/dev/null || echo "0")
            local lines_deleted=$(echo "$file_analysis" | jq -r '.summary.lines_deleted' 2>/dev/null || echo "0")
            
            # ファイルのステータスを確認
            local added_files=$(git diff --cached --name-status | grep "^A" | wc -l)
            local modified_files=$(git diff --cached --name-status | grep "^M" | wc -l)
            local deleted_files=$(git diff --cached --name-status | grep "^D" | wc -l)
            
            if [[ $added_files -gt 0 ]] && [[ $modified_files -eq 0 ]] && [[ $deleted_files -eq 0 ]]; then
                if [[ $added_files -eq 1 ]]; then
                    fallback_message="新しいファイルを追加"
                else
                    fallback_message="${added_files}個のファイルを追加"
                fi
            elif [[ $modified_files -gt 0 ]] && [[ $added_files -eq 0 ]] && [[ $deleted_files -eq 0 ]]; then
                if [[ $modified_files -eq 1 ]]; then
                    fallback_message="ファイルを更新"
                else
                    fallback_message="${modified_files}個のファイルを更新"
                fi
            elif [[ $deleted_files -gt 0 ]] && [[ $added_files -eq 0 ]] && [[ $modified_files -eq 0 ]]; then
                if [[ $deleted_files -eq 1 ]]; then
                    fallback_message="ファイルを削除"
                else
                    fallback_message="${deleted_files}個のファイルを削除"
                fi
            else
                # 混在している場合
                local total_files=$((added_files + modified_files + deleted_files))
                if [[ $total_files -eq 1 ]]; then
                    fallback_message="ファイルを変更"
                else
                    fallback_message="${total_files}個のファイルを変更"
                fi
            fi
        else
            fallback_message="変更をコミット"
        fi
        
        log_info "フォールバックメッセージを生成: $fallback_message"
        response="$fallback_message"
    fi
    
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
        timeout=$(echo "$config" | jq -r '.gemini.timeout // 60')
        language=$(echo "$config" | jq -r '.commit_message.language // "ja"')
        max_length=$(echo "$config" | jq -r '.commit_message.max_length // 50')
    else
        # jqが使用できない場合のデフォルト値
        model="gemini-pro"
        temperature="0.3"
        max_tokens="100"
        timeout="60"
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
        log_warn "Gemini CLI呼び出しが失敗しました（タイムアウト: ${timeout}秒）。フォールバック機能を使用します。"
        
        # フォールバック：ファイル状態から簡単なメッセージを生成
        local fallback_message
        fallback_message=$(generate_fallback_message "$file_analysis")
        echo "$fallback_message"
        log_info "フォールバックメッセージ生成完了"
        return 0
    fi
    
    # レスポンス後処理
    local processed_message
    processed_message=$(process_response "$response" "$max_length" "$file_analysis")
    
    echo "$processed_message"
    log_info "コミットメッセージ生成完了"
    return 0
}

# フォールバック：ファイル状態から簡単なコミットメッセージを生成
generate_fallback_message() {
    local file_analysis="$1"
    
    log_info "フォールバック機能でコミットメッセージを生成中..."
    
    # Git diff統計を取得
    local added_files=$(git diff --cached --name-status | grep "^A" | wc -l)
    local modified_files=$(git diff --cached --name-status | grep "^M" | wc -l)
    local deleted_files=$(git diff --cached --name-status | grep "^D" | wc -l)
    local total_files=$((added_files + modified_files + deleted_files))
    
    # ファイル名を取得（最初の数個）
    local changed_files=$(git diff --cached --name-only | head -3 | tr '\n' ', ' | sed 's/,$//')
    
    # メッセージ生成
    local message=""
    
    if [[ $total_files -eq 0 ]]; then
        message="Update files"
    elif [[ $added_files -gt 0 ]] && [[ $modified_files -eq 0 ]] && [[ $deleted_files -eq 0 ]]; then
        if [[ $added_files -eq 1 ]]; then
            message="Add new file: $changed_files"
        else
            message="Add $added_files new files"
        fi
    elif [[ $modified_files -gt 0 ]] && [[ $added_files -eq 0 ]] && [[ $deleted_files -eq 0 ]]; then
        if [[ $modified_files -eq 1 ]]; then
            message="Update file: $changed_files"
        else
            message="Update $modified_files files"
        fi
    elif [[ $deleted_files -gt 0 ]] && [[ $added_files -eq 0 ]] && [[ $modified_files -eq 0 ]]; then
        if [[ $deleted_files -eq 1 ]]; then
            message="Delete file: $changed_files"
        else
            message="Delete $deleted_files files"
        fi
    else
        # 混合の場合
        message="Update $total_files files"
        if [[ -n "$changed_files" ]]; then
            message="$message: $changed_files"
        fi
    fi
    
    # 最大長を考慮してトリム
    if [[ ${#message} -gt 72 ]]; then
        message="${message:0:69}..."
    fi
    
    echo "$message"
    log_debug "フォールバックメッセージ: $message"
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