#!/bin/bash
# エラーハンドリングシステム

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# エラータイプ定義
declare -A ERROR_TYPES=(
    ["SYSTEM_ERROR"]=1
    ["NETWORK_ERROR"]=2
    ["API_ERROR"]=3
    ["GIT_ERROR"]=4
    ["CONFIG_ERROR"]=5
    ["USER_ERROR"]=6
)

# エラーコード定義
declare -A ERROR_CODES=(
    ["SUCCESS"]=0
    ["GENERIC_ERROR"]=1
    ["GEMINI_CLI_NOT_FOUND"]=10
    ["GEMINI_API_ERROR"]=11
    ["GEMINI_TIMEOUT"]=12
    ["GEMINI_RATE_LIMIT"]=13
    ["GIT_NO_STAGED_FILES"]=20
    ["GIT_NOT_REPOSITORY"]=21
    ["GIT_DIFF_ERROR"]=22
    ["CONFIG_INVALID"]=30
    ["CONFIG_NOT_FOUND"]=31
    ["NETWORK_TIMEOUT"]=40
    ["NETWORK_CONNECTION"]=41
)

# エラーメッセージ生成
generate_error_message() {
    local error_code="$1"
    local context="${2:-}"
    
    case "$error_code" in
        "${ERROR_CODES["GEMINI_CLI_NOT_FOUND"]}")
            cat <<EOF
❌ Gemini CLIがインストールされていません

解決方法:
  1. Node.js版をインストール:
     npm install -g @google/generative-ai-cli
     
  2. Python版をインストール:
     pip install google-generativeai-cli
     
  3. インストール後、APIキーを設定:
     export GEMINI_API_KEY="your-api-key"

詳細: https://ai.google.dev/docs/setup
EOF
            ;;
            
        "${ERROR_CODES["GEMINI_API_ERROR"]}")
            cat <<EOF
❌ Gemini API呼び出しエラー

考えられる原因:
  • APIキーが設定されていない
  • APIキーが無効
  • API利用制限に達している
  • ネットワーク接続の問題

解決方法:
  1. APIキーを確認:
     echo \$GEMINI_API_KEY
     
  2. APIキーを再設定:
     export GEMINI_API_KEY="your-api-key"
     
  3. Gemini CLIの動作確認:
     echo "こんにちは" | gemini
     
  4. API利用状況を確認:
     https://aistudio.google.com/app/apikey

エラー詳細: $context
EOF
            ;;
            
        "${ERROR_CODES["GEMINI_TIMEOUT"]}")
            cat <<EOF
❌ Gemini API接続タイムアウト

解決方法:
  1. ネットワーク接続を確認
  2. しばらく待ってから再試行
  3. 設定でタイムアウト時間を延長:
     ~/.config/ai-commit-generator/config.yml
     gemini:
       timeout: 60  # 秒数を増加

現在のタイムアウト設定: $context 秒
EOF
            ;;
            
        "${ERROR_CODES["GEMINI_RATE_LIMIT"]}")
            cat <<EOF
❌ Gemini APIレート制限に達しました

解決方法:
  1. しばらく待ってから再試行（推奨: 1分後）
  2. 有料プランの検討
  3. 使用頻度を調整

API制限情報: https://ai.google.dev/pricing
EOF
            ;;
            
        "${ERROR_CODES["GIT_NO_STAGED_FILES"]}")
            cat <<EOF
❌ ステージされたファイルがありません

解決方法:
  1. ファイルをステージしてください:
     git add <ファイル名>
     
  2. すべての変更をステージ:
     git add .
     
  3. Lazygitでファイルを選択してスペースキーでステージ

現在のステータス:
$(git status --porcelain 2>/dev/null | head -5 || echo "  変更されたファイルがありません")
EOF
            ;;
            
        "${ERROR_CODES["GIT_NOT_REPOSITORY"]}")
            cat <<EOF
❌ Gitリポジトリではありません

解決方法:
  1. Gitリポジトリを初期化:
     git init
     
  2. 既存のリポジトリに移動
  
  3. Gitリポジトリをクローン:
     git clone <リポジトリURL>

現在の場所: $(pwd)
EOF
            ;;
            
        "${ERROR_CODES["CONFIG_INVALID"]}")
            cat <<EOF
❌ 設定ファイルが無効です

解決方法:
  1. 設定ファイルの構文を確認:
     ~/.config/ai-commit-generator/config.yml
     
  2. サンプル設定を生成:
     ai-commit-generator --generate-sample-config
     
  3. 設定をリセット:
     rm ~/.config/ai-commit-generator/config.yml

エラー詳細: $context
EOF
            ;;
            
        "${ERROR_CODES["CONFIG_NOT_FOUND"]}")
            cat <<EOF
❌ 設定ファイルが見つかりません

初回セットアップ手順:
  1. 設定ディレクトリを作成:
     mkdir -p ~/.config/ai-commit-generator
     
  2. サンプル設定ファイルを生成:
     ai-commit-generator --generate-sample-config
     
  3. 設定ファイルを編集（オプション）:
     ~/.config/ai-commit-generator/config/default.yml
     
  4. Gemini APIキーを設定:
     export GEMINI_API_KEY="your-api-key"

💡 設定ファイルがなくてもデフォルト設定で動作します

設定ファイルの場所: $context
EOF
            ;;
            
        "${ERROR_CODES["NETWORK_CONNECTION"]}")
            cat <<EOF
❌ ネットワーク接続エラー

解決方法:
  1. インターネット接続を確認
  2. プロキシ設定を確認
  3. ファイアウォール設定を確認
  4. DNS設定を確認

ネットワーク診断:
  ping -c 1 google.com
  nslookup ai.google.dev
EOF
            ;;
            
        *)
            cat <<EOF
❌ 予期しないエラーが発生しました

エラーコード: $error_code
コンテキスト: $context

トラブルシューティング:
  1. 最新バージョンに更新
  2. 設定ファイルをリセット
  3. ログファイルを確認
  4. GitHub Issuesで報告

ログの場所: \$HOME/.config/ai-commit-generator/logs/
EOF
            ;;
    esac
}

# エラーをログに記録
log_error_details() {
    local error_code="$1"
    local context="${2:-}"
    local stack_trace="${3:-}"
    
    log_error "エラー発生 - コード: $error_code, コンテキスト: $context"
    
    if [[ -n "$stack_trace" ]]; then
        log_debug "スタックトレース: $stack_trace"
    fi
    
    # システム情報をログに記録
    log_debug "システム情報:"
    log_debug "  OS: $(uname -s) $(uname -r)"
    log_debug "  シェル: $SHELL"
    log_debug "  作業ディレクトリ: $(pwd)"
    log_debug "  Git バージョン: $(git --version 2>/dev/null || echo 'Git not found')"
    log_debug "  Gemini CLI: $(which gemini 2>/dev/null || echo 'Not found')"
}

# エラーハンドラー関数
handle_error() {
    local error_code="$1"
    local context="${2:-}"
    local show_message="${3:-true}"
    
    # エラーをログに記録
    log_error_details "$error_code" "$context"
    
    # ユーザーにエラーメッセージを表示
    if [[ "$show_message" == "true" ]]; then
        generate_error_message "$error_code" "$context" >&2
    fi
    
    # 適切な終了コードを返す
    exit "$error_code"
}

# 回復可能なエラーハンドラー
handle_recoverable_error() {
    local error_code="$1"
    local context="${2:-}"
    local recovery_action="${3:-}"
    
    log_warn "回復可能なエラー - コード: $error_code, コンテキスト: $context"
    
    generate_error_message "$error_code" "$context" >&2
    
    if [[ -n "$recovery_action" ]]; then
        echo >&2
        echo "代替手段: $recovery_action" >&2
    fi
    
    return "$error_code"
}

# 特定のエラータイプをチェック
check_gemini_cli_error() {
    local exit_code="$1"
    local output="${2:-}"
    
    case "$exit_code" in
        127)
            handle_error "${ERROR_CODES["GEMINI_CLI_NOT_FOUND"]}"
            ;;
        124)
            handle_error "${ERROR_CODES["GEMINI_TIMEOUT"]}"
            ;;
        1)
            if echo "$output" | grep -q -i "rate limit\|quota\|limit exceeded"; then
                handle_error "${ERROR_CODES["GEMINI_RATE_LIMIT"]}" "$output"
            else
                handle_error "${ERROR_CODES["GEMINI_API_ERROR"]}" "$output"
            fi
            ;;
        *)
            handle_error "${ERROR_CODES["GEMINI_API_ERROR"]}" "Unexpected exit code: $exit_code"
            ;;
    esac
}

# Gitエラーチェック
check_git_error() {
    local exit_code="$1"
    local command="$2"
    local output="${3:-}"
    
    if [[ $exit_code -ne 0 ]]; then
        case "$command" in
            *"diff --cached"*)
                if echo "$output" | grep -q "not a git repository"; then
                    handle_error "${ERROR_CODES["GIT_NOT_REPOSITORY"]}"
                else
                    handle_error "${ERROR_CODES["GIT_DIFF_ERROR"]}" "$output"
                fi
                ;;
            *)
                handle_error "${ERROR_CODES["GIT_DIFF_ERROR"]}" "$output"
                ;;
        esac
    fi
}

# 設定エラーチェック
check_config_error() {
    local config_file="$1"
    local error_output="${2:-}"
    
    if [[ ! -f "$config_file" ]]; then
        handle_recoverable_error "${ERROR_CODES["CONFIG_NOT_FOUND"]}" "$config_file" \
            "デフォルト設定を使用します"
        return 0
    fi
    
    if [[ -n "$error_output" ]]; then
        handle_error "${ERROR_CODES["CONFIG_INVALID"]}" "$error_output"
    fi
}

# グローバルエラーハンドラー設定
setup_error_handlers() {
    set -Eeuo pipefail
    
    # ERRトラップを設定
    trap 'handle_error ${ERROR_CODES["GENERIC_ERROR"]} "Line $LINENO in $BASH_SOURCE"' ERR
    
    # シグナルハンドラー
    trap 'handle_error ${ERROR_CODES["GENERIC_ERROR"]} "Interrupted by user"' INT
    trap 'handle_error ${ERROR_CODES["GENERIC_ERROR"]} "Terminated"' TERM
}

# エラー状況の診断
diagnose_system() {
    echo "🔍 システム診断を実行中..."
    echo
    
    # Git の確認
    echo "Git 環境:"
    if git --version >/dev/null 2>&1; then
        echo "  ✅ Git: $(git --version)"
        if git rev-parse --git-dir >/dev/null 2>&1; then
            echo "  ✅ Gitリポジトリ: $(git rev-parse --show-toplevel)"
        else
            echo "  ❌ Gitリポジトリではありません"
        fi
    else
        echo "  ❌ Git がインストールされていません"
    fi
    echo
    
    # Gemini CLI の確認
    echo "Gemini CLI 環境:"
    if command -v gemini >/dev/null 2>&1; then
        echo "  ✅ Gemini CLI: $(which gemini)"
        if [[ -n "${GEMINI_API_KEY:-}" ]]; then
            echo "  ✅ APIキー: 設定済み"
        else
            echo "  ❌ APIキー: 未設定"
        fi
    else
        echo "  ❌ Gemini CLI がインストールされていません"
    fi
    echo
    
    # 依存関係の確認
    echo "依存関係:"
    for cmd in jq yq; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✅ $cmd: $(which $cmd)"
        else
            echo "  ⚠️  $cmd: 未インストール（オプション）"
        fi
    done
    echo
    
    # ネットワークの確認
    echo "ネットワーク接続:"
    if ping -c 1 google.com >/dev/null 2>&1; then
        echo "  ✅ インターネット接続: 正常"
    else
        echo "  ❌ インターネット接続: 失敗"
    fi
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "diagnose")
            diagnose_system
            ;;
        "test-error")
            error_code="${2:-${ERROR_CODES["GEMINI_CLI_NOT_FOUND"]}}"
            generate_error_message "$error_code" "テストエラー"
            ;;
        *)
            echo "使用方法: $0 [diagnose|test-error]"
            echo "  diagnose   - システム診断を実行"
            echo "  test-error - エラーメッセージのテスト"
            ;;
    esac
fi