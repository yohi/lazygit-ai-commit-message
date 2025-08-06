#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

readonly DEFAULT_CONFIG_FILE="$HOME/.config/lazygit/gemini-commit.yml"
readonly SCRIPT_DIR_CONFIG_FILE="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/config/gemini-commit.yml"

GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-pro}"
GEMINI_TEMPERATURE="${GEMINI_TEMPERATURE:-0.3}"
GEMINI_MAX_TOKENS="${GEMINI_MAX_TOKENS:-200}"
GEMINI_TIMEOUT="${GEMINI_TIMEOUT:-30}"
COMMIT_LANGUAGE="${COMMIT_LANGUAGE:-ja}"
COMMIT_FORMAT="${COMMIT_FORMAT:-conventional}"
MAX_DIFF_SIZE="${MAX_DIFF_SIZE:-10000}"
SHOW_PROGRESS="${SHOW_PROGRESS:-true}"
CONFIRM_BEFORE_COMMIT="${CONFIRM_BEFORE_COMMIT:-true}"
AUTO_COMMIT="${AUTO_COMMIT:-false}"
EDITOR_COMMAND="${EDITOR_COMMAND:-${EDITOR:-vim}}"

load_config() {
    local config_file="$DEFAULT_CONFIG_FILE"
    
    log_debug "設定読み込みを開始します"
    
    if [ ! -f "$config_file" ]; then
        if [ -f "$SCRIPT_DIR_CONFIG_FILE" ]; then
            config_file="$SCRIPT_DIR_CONFIG_FILE"
            log_debug "スクリプトディレクトリの設定ファイルを使用します: $config_file"
        else
            log_debug "設定ファイルが見つかりません。デフォルト設定を使用します"
            return $ERROR_SUCCESS
        fi
    else
        log_debug "ユーザー設定ファイルを使用します: $config_file"
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        log_debug "yqコマンドが利用できません。デフォルト設定を使用します"
        return $ERROR_SUCCESS
    fi
    
    local yq_version
    yq_version=$(yq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | cut -d'v' -f2 | cut -d'.' -f1)
    if [ -z "$yq_version" ] || [ "$yq_version" -lt 4 ]; then
        log_debug "yq バージョンが古すぎます（v4+必要）。デフォルト設定を使用します"
        return $ERROR_SUCCESS
    fi
    
    local temp_env_file
    temp_env_file=$(create_secure_temp_file)
    
    if yq eval -o=shell "$config_file" > "$temp_env_file" 2>/dev/null; then
        source "$temp_env_file"
        log_debug "設定ファイルの読み込み完了"
    else
        show_warning "設定ファイルの解析に失敗しました: $config_file"
        show_info "デフォルト設定を使用します"
    fi
    
    rm -f "$temp_env_file"
    
    validate_config
    return $ERROR_SUCCESS
}

validate_config() {
    log_debug "設定値の検証を開始します"
    
    if [[ ! "$GEMINI_TEMPERATURE" =~ ^[0-9]*\.?[0-9]+$ ]] || 
       (( $(echo "$GEMINI_TEMPERATURE > 2.0" | bc -l) )) || 
       (( $(echo "$GEMINI_TEMPERATURE < 0.0" | bc -l) )); then
        show_warning "無効な temperature 値: $GEMINI_TEMPERATURE (0.0-2.0 の範囲で指定)"
        GEMINI_TEMPERATURE="0.3"
    fi
    
    if [[ ! "$GEMINI_MAX_TOKENS" =~ ^[0-9]+$ ]] || [ "$GEMINI_MAX_TOKENS" -le 0 ]; then
        show_warning "無効な max_tokens 値: $GEMINI_MAX_TOKENS"
        GEMINI_MAX_TOKENS="200"
    fi
    
    if [[ ! "$GEMINI_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$GEMINI_TIMEOUT" -le 0 ]; then
        show_warning "無効な timeout 値: $GEMINI_TIMEOUT"
        GEMINI_TIMEOUT="30"
    fi
    
    if [[ ! "$MAX_DIFF_SIZE" =~ ^[0-9]+$ ]] || [ "$MAX_DIFF_SIZE" -le 0 ]; then
        show_warning "無効な max_diff_size 値: $MAX_DIFF_SIZE"
        MAX_DIFF_SIZE="10000"
    fi
    
    case "$COMMIT_LANGUAGE" in
        "ja"|"en"|"zh"|"ko"|"es"|"fr"|"de")
            ;;
        *)
            show_warning "サポートされていない言語: $COMMIT_LANGUAGE"
            COMMIT_LANGUAGE="ja"
            ;;
    esac
    
    case "$COMMIT_FORMAT" in
        "conventional"|"simple"|"free")
            ;;
        *)
            show_warning "サポートされていない形式: $COMMIT_FORMAT"
            COMMIT_FORMAT="conventional"
            ;;
    esac
    
    log_debug "設定値検証完了"
}

show_config() {
    echo "========================================="
    echo "現在の設定:"
    echo "========================================="
    echo "Gemini設定:"
    echo "  モデル: $GEMINI_MODEL"
    echo "  温度: $GEMINI_TEMPERATURE"
    echo "  最大トークン数: $GEMINI_MAX_TOKENS"
    echo "  タイムアウト: ${GEMINI_TIMEOUT}秒"
    echo ""
    echo "コミット設定:"
    echo "  言語: $COMMIT_LANGUAGE"
    echo "  形式: $COMMIT_FORMAT"
    echo "  最大差分サイズ: ${MAX_DIFF_SIZE}bytes"
    echo ""
    echo "UI設定:"
    echo "  進行状況表示: $SHOW_PROGRESS"
    echo "  コミット前確認: $CONFIRM_BEFORE_COMMIT"
    echo "  エディタ: $EDITOR_COMMAND"
    echo "========================================="
}

create_default_config() {
    local output_file="${1:-$DEFAULT_CONFIG_FILE}"
    
    log_debug "デフォルト設定ファイルを作成します: $output_file"
    
    local config_dir
    config_dir=$(dirname "$output_file")
    
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir" || {
            show_error "設定ディレクトリの作成に失敗しました: $config_dir"
            return $ERROR_CONFIG
        }
    fi
    
    cat > "$output_file" <<EOF
gemini:
  model: "gemini-1.5-flash"
  temperature: 0.3
  max_tokens: 200
  timeout: 30
  
commit:
  language: "ja"
  format: "conventional"
  max_diff_size: 10000
  
prompts:
  system: |
    あなたは優秀な開発者です。
    git diffを分析して適切なコミットメッセージを生成してください。
  
  user_template: |
    以下の変更に対するコミットメッセージを{language}で生成してください。
    
    要件:
    - Conventional Commits形式に従う ({format})
    - 50文字以内の簡潔な要約行
    - 必要に応じて詳細説明を追加
    - 変更の意図と影響を明確に表現
    
    変更内容:
    {diff_content}
    
    コミットメッセージ:

ui:
  show_progress: true
  confirm_before_commit: true
  editor_command: "\${EDITOR:-vim}"
EOF
    
    show_success "デフォルト設定ファイルを作成しました: $output_file"
    return $ERROR_SUCCESS
}