#!/bin/bash
# 🤖 Gemini 2.5 Flash API 直接統合クライアント（修正版）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_debug() { echo "[DEBUG] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
}

# Gemini API キーチェック
check_gemini_api_key() {
    if [ -z "${GEMINI_API_KEY:-}" ]; then
        log_error "GEMINI_API_KEY が設定されていません"
        return 1
    fi
    return 0
}

# Git差分の解析（ステージされたファイルのみ）
analyze_git_changes() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Gitリポジトリではありません"
        return 1
    fi
    
    # ステージされた変更を取得
    local diff_content=$(git diff --cached 2>/dev/null || echo "")
    if [ -z "$diff_content" ]; then
        log_warn "ステージされた変更が検出されませんでした"
        return 1
    fi
    
    # 変更統計
    local file_count=$(git diff --cached --name-only | wc -l)
    local added_lines=$(git diff --cached --numstat | awk '{added+=$1} END {print added+0}')
    local deleted_lines=$(git diff --cached --numstat | awk '{deleted+=$2} END {print deleted+0}')
    local changed_files=$(git diff --cached --name-only | head -10)
    local first_file=$(echo "$changed_files" | head -1 | xargs basename)
    
    # コンテキスト判定
    local context=""
    if echo "$first_file" | grep -q "config\|\.yml$\|\.yaml$\|\.json$\|\.toml$\|\.ini$"; then
        context="設定ファイル"
    elif echo "$first_file" | grep -q "\.md$\|README\|docs"; then
        context="ドキュメント"
    elif echo "$first_file" | grep -q "\.sh$\|scripts"; then
        context="スクリプト"
    elif echo "$first_file" | grep -q "\.js$\|\.ts$\|\.tsx$"; then
        context="JavaScript/TypeScript"
    elif echo "$first_file" | grep -q "\.py$"; then
        context="Python"
    else
        context="プロジェクトファイル"
    fi
    
    # 差分のクリーンアップ（ヘッダー除去）
    local clean_diff=$(echo "$diff_content" | grep -v "^diff --git" | grep -v "^index " | grep -v "^--- " | grep -v "^+++ " | grep -v "^@@ " | head -20)
    
    # 追加情報
    local branch_name=$(git branch --show-current 2>/dev/null || echo "unknown")
    local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
    
    # JSON出力
    jq -n \
        --arg first_file "$first_file" \
        --arg context "$context" \
        --arg file_count "$file_count" \
        --arg added_lines "$added_lines" \
        --arg deleted_lines "$deleted_lines" \
        --arg branch_name "$branch_name" \
        --arg repo_name "$repo_name" \
        --arg clean_diff "$clean_diff" \
        --argjson changed_files "$(echo "$changed_files" | jq -R . | jq -s .)" \
        '{
            first_file: $first_file,
            context: $context,
            file_count: ($file_count | tonumber),
            added_lines: ($added_lines | tonumber),
            deleted_lines: ($deleted_lines | tonumber),
            branch_name: $branch_name,
            repo_name: $repo_name,
            clean_diff: $clean_diff,
            changed_files: $changed_files
        }'
}

# Gemini API呼び出し
call_gemini_api() {
    local prompt="$1"
    local model="${2:-gemini-2.5-flash}"
    local temperature="${3:-0.4}"
    local max_tokens="${4:-1000}"
    
    log_info "Gemini API 呼び出し中..." >&2
    
    local json_payload=$(jq -n \
        --arg text "$prompt" \
        --arg temp "$temperature" \
        --arg tokens "$max_tokens" \
        '{
            "contents": [{
                "parts": [{
                    "text": $text
                }]
            }],
            "generationConfig": {
                "temperature": ($temp | tonumber),
                "maxOutputTokens": ($tokens | tonumber),
                "stopSequences": ["\n"]
            }
        }')
    
    local api_response=""
    if api_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}" \
        2>/dev/null); then
        
        local ai_message=$(echo "$api_response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || echo "")
        
        if echo "$api_response" | jq -e '.error' >/dev/null 2>&1; then
            local error_msg=$(echo "$api_response" | jq -r '.error.message' 2>/dev/null || echo "API エラー")
            local error_code=$(echo "$api_response" | jq -r '.error.code' 2>/dev/null || echo "unknown")
            log_error "Gemini API エラー [${error_code}]: $error_msg" >&2
            log_debug "Full API response: $api_response" >&2
            return 1
        fi
        
        if [ -n "$ai_message" ] && [ "$ai_message" != "null" ]; then
            echo "$ai_message"
            return 0
        else
            log_error "Gemini API から有効なレスポンスが得られませんでした" >&2
            log_debug "AI message: '$ai_message'" >&2
            log_debug "API response: $api_response" >&2
            return 1
        fi
    else
        log_error "Gemini API 接続失敗" >&2
        return 1
    fi
}

# 実用的なコミットメッセージ生成（フォールバック）
generate_practical_commit_message() {
    local analysis="$1"
    
    local first_file=$(echo "$analysis" | jq -r '.first_file')
    local context=$(echo "$analysis" | jq -r '.context')
    local file_count=$(echo "$analysis" | jq -r '.file_count')
    local added_lines=$(echo "$analysis" | jq -r '.added_lines')
    local deleted_lines=$(echo "$analysis" | jq -r '.deleted_lines')
    
    local action=""
    local scope=""
    local description=""
    
    # アクションの決定
    if echo "$first_file" | grep -q "test\|spec"; then
        action="test"
        description="テストを更新"
    elif echo "$first_file" | grep -q "\.md$\|README\|docs"; then
        action="docs"
        description="ドキュメントを更新"
    elif echo "$first_file" | grep -q "config\|\.yml$\|\.yaml$\|\.json$"; then
        action="chore"
        description="設定を更新"
    elif echo "$first_file" | grep -q "gemini\|ai"; then
        action="feat"
        description="AI機能を改善"
    elif [ $added_lines -gt $deleted_lines ] && [ $((added_lines - deleted_lines)) -gt 20 ]; then
        action="feat"
        description="機能を追加"
    elif [ $deleted_lines -gt $added_lines ] && [ $((deleted_lines - added_lines)) -gt 20 ]; then
        action="refactor"
        description="コードを整理"
    else
        action="fix"
        description="を改善"
    fi
    
    # スコープの決定
    if echo "$first_file" | grep -q "config\|\.yml$\|\.yaml$\|\.json$"; then
        scope="config"
    elif echo "$first_file" | grep -q "\.md$\|README\|docs"; then
        scope="docs"
    elif echo "$first_file" | grep -q "\.sh$\|scripts"; then
        scope="scripts"
    elif echo "$first_file" | grep -q "ai\|gemini"; then
        scope="ai"
    elif echo "$first_file" | grep -q "test\|spec"; then
        scope="test"
    else
        scope=""
    fi
    
    # メッセージ構築（より具体的に）
    local message=""
    if [ "$file_count" -gt 1 ]; then
        # 複数ファイルの場合、変更の種類を分析
        local all_files=$(echo "$analysis" | jq -r '.changed_files[]')
        
        # ファイルタイプ分析
        local has_scripts=$(echo "$all_files" | grep -c "\.sh$\|scripts/" || echo 0)
        local has_docs=$(echo "$all_files" | grep -c "\.md$\|README\|docs" || echo 0)
        local has_config=$(echo "$all_files" | grep -c "config\|\.yml$\|\.yaml$\|\.json$" || echo 0)
        local has_src=$(echo "$all_files" | grep -c "src/" || echo 0)
        local has_ai=$(echo "$all_files" | grep -c "ai\|gemini" || echo 0)
        
        # より具体的で意味のある説明を生成
        if [ "$has_ai" -gt 0 ] && [ "$has_scripts" -gt 0 ]; then
            message="feat(ai): Gemini API統合コミットメッセージ生成機能を実装"
        elif [ "$has_scripts" -gt 0 ] && [ "$has_src" -gt 0 ]; then
            message="feat(scripts): AI統合スクリプトシステムを実装"
        elif [ "$has_config" -gt 0 ] && [ "$has_scripts" -gt 0 ]; then
            message="feat(config): 設定ファイルとスクリプトを統合実装"
        elif [ "$has_scripts" -gt 1 ]; then
            message="refactor(scripts): スクリプト機能を統合リファクタリング"
        elif [ "$has_config" -gt 0 ] && [ "$has_src" -gt 0 ]; then
            message="chore: 設定とソースコードを同期更新"
        elif [ "$has_docs" -gt 0 ] && [ "$file_count" -gt 2 ]; then
            message="docs: ドキュメントと関連ファイルを包括更新"
        else
            # 変更パターンに基づいた具体的説明
            local new_files=$(git diff --cached --name-status | grep "^A" | wc -l)
            local modified_files=$(git diff --cached --name-status | grep "^M" | wc -l)
            local deleted_files=$(git diff --cached --name-status | grep "^D" | wc -l)
            
            if [ "$new_files" -gt "$modified_files" ]; then
                # 新規ファイルが多い場合
                if echo "$first_file" | grep -q "\.sh$"; then
                    message="feat(scripts): 新規スクリプトコンポーネントを追加"
                elif echo "$first_file" | grep -q "\.md$"; then
                    message="docs: 新規ドキュメントファイルを追加"
                elif echo "$first_file" | grep -q "config\|\.yml$"; then
                    message="feat(config): 新規設定ファイルを追加"
                else
                    message="feat: 新規機能コンポーネントを追加"
                fi
            elif [ "$deleted_files" -gt 0 ]; then
                # 削除ファイルがある場合
                message="refactor: 不要ファイルの削除とコード整理"
            elif [ "$added_lines" -gt $((deleted_lines * 3)) ]; then
                # 大幅な追加の場合
                message="feat: 機能拡張と新規実装"
            elif [ "$deleted_lines" -gt $((added_lines * 2)) ]; then
                # 大幅な削除の場合
                message="refactor: コード簡素化とリファクタリング"
            else
                # 通常の修正の場合
                if echo "$first_file" | grep -q "\.sh$"; then
                    message="fix(scripts): スクリプト動作の修正と改善"
                elif echo "$first_file" | grep -q "\.md$"; then
                    message="docs: ドキュメント内容の修正と更新"
                elif echo "$first_file" | grep -q "config\|\.yml$"; then
                    message="fix(config): 設定の修正と調整"
                else
                    message="fix: 機能動作の修正と安定性向上"
                fi
            fi
        fi
    elif [ -n "$scope" ]; then
        # ファイル名の改善処理
        local name=$(basename "$first_file" | sed 's/\.[^.]*$//')
        if [ "$name" = "test" ] || [ "$name" = "config" ] || [ "$name" = "README" ]; then
            # 汎用ファイル名の場合はより具体的に
            if [ "$name" = "test" ]; then
                message="${action}(${scope}): テストファイルを${description}"
            elif [ "$name" = "config" ]; then
                message="${action}(${scope}): 設定ファイルを${description}"
            elif [ "$name" = "README" ]; then
                message="${action}(${scope}): プロジェクト説明を${description}"
            fi
        else
            local clean_name=$(echo "$name" | sed 's/_/ /g')
            message="${action}(${scope}): ${clean_name}を${description}"
        fi
    else
        local name=$(basename "$first_file" | sed 's/\.[^.]*$//')
        if [ "$name" = "test" ]; then
            message="${action}: テストファイルを${description}"
        elif [ "$name" = "config" ]; then
            message="${action}: 設定を${description}"
        elif [ "$name" = "README" ]; then
            message="${action}: プロジェクト説明を${description}"
        else
            local clean_name=$(echo "$name" | sed 's/_/ /g')
            message="${action}: ${clean_name}を${description}"
        fi
    fi
    
    echo "$message"
}

# メイン実行関数
generate_gemini_commit_message() {
    local mode="${1:-display}"
    
    log_info "Gemini API でコミットメッセージ生成中..." >&2
    
    # API キーチェック
    if ! check_gemini_api_key; then
        return 1
    fi
    
    # Git変更の解析
    local analysis=""
    if ! analysis=$(analyze_git_changes); then
        return 1
    fi
    
    local first_file=$(echo "$analysis" | jq -r '.first_file')
    local context=$(echo "$analysis" | jq -r '.context')
    local added_lines=$(echo "$analysis" | jq -r '.added_lines')
    local deleted_lines=$(echo "$analysis" | jq -r '.deleted_lines')
    local file_count=$(echo "$analysis" | jq -r '.file_count')
    local all_files=$(echo "$analysis" | jq -r '.changed_files[]' | tr '\n' ', ' | sed 's/, $//')
    
    # ファイル数に応じたプロンプト生成
    local prompt=""
    if [ "$file_count" -eq 1 ]; then
        prompt="以下のファイル変更に対する1行のコミットメッセージを生成してください。

ファイル: ${first_file}
変更: +${added_lines}行追加 -${deleted_lines}行削除

形式: type(scope): 説明
type: feat, fix, docs, chore のいずれか
説明: 何をしたかを日本語で簡潔に

日本語コミットメッセージ:"
    else
        prompt="以下の複数ファイル変更から、変更の本質を理解して1行のコミットメッセージを生成してください。

変更ファイル数: ${file_count}個
主要ファイル: ${first_file}
全ファイル: ${all_files}
変更統計: +${added_lines}行追加 -${deleted_lines}行削除

重要な指示:
- 単純に「○個のファイルを更新」は禁止
- 変更の目的や機能を具体的に説明
- 新機能追加、バグ修正、リファクタリング、設定変更など具体的な内容
- ファイル内容から変更の意図を推測

形式: type(scope): 具体的な変更内容の説明
type: feat, fix, docs, chore, refactor のいずれか

日本語コミットメッセージ:"
    fi
    
    # Gemini API 呼び出し
    local ai_response=""
    local final_message=""
    local model="gemini-2.5-flash"
    
    if ai_response=$(call_gemini_api "$prompt" "$model"); then
        # レスポンスのクリーンアップとコミットメッセージ抽出
        ai_response=$(echo "$ai_response" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["\`]*//' | sed 's/["\`]*$//')
        
        # "コミットメッセージ:" の後の部分を抽出、なければ最初の行
        if echo "$ai_response" | grep -q "コミットメッセージ:\|日本語コミットメッセージ:"; then
            ai_response=$(echo "$ai_response" | sed -n 's/.*\(日本語\)\?コミットメッセージ:[[:space:]]*//p' | head -1)
        else
            ai_response=$(echo "$ai_response" | head -1)
        fi
        
        # 不適切なレスポンスチェック
        if echo "$ai_response" | grep -q "+++\|---\|@@\|diff --git"; then
            log_warn "不適切なレスポンス、フォールバック" >&2
            final_message=$(generate_practical_commit_message "$analysis")
        elif [ ${#ai_response} -gt 10 ]; then
            # レスポンスの最初の行を使用（切り取りなし）
            final_message=$(echo "$ai_response" | head -1)
            log_info "Gemini レスポンス採用（${#final_message}文字）" >&2
        else
            final_message=$(generate_practical_commit_message "$analysis")
            log_info "フォールバック採用（レスポンス長: ${#ai_response}）" >&2
        fi
    else
        final_message=$(generate_practical_commit_message "$analysis")
        log_info "API失敗、フォールバック採用" >&2
    fi
    
    # ファイル保存
    echo "$final_message" > /tmp/lazygit_ai_commit_message.txt
    
    # 出力
    case "$mode" in
        "display")
            echo "✅ Gemini AI 生成完了" >&2
            echo "" >&2
            echo "📝 AIコミットメッセージ:" >&2
            echo "\"${final_message}\"" >&2
            echo "" >&2
            echo "🧠 Gemini AI 情報:" >&2
            echo "  • モデル: $model" >&2
            echo "  • 温度: 0.4" >&2
            echo "  • コンテキスト: ${context}" >&2
            echo "" >&2
            echo "📊 変更統計:" >&2
            echo "  • ファイル数: ${file_count}" >&2
            echo "  • 追加行数: ${added_lines}" >&2
            echo "  • 削除行数: ${deleted_lines}" >&2
            ;;
        "message_only")
            echo "$final_message"
            ;;
        "quiet")
            # 静かモード
            ;;
        *)
            echo "$final_message"
            ;;
    esac
    
    return 0
}

# 直接実行時
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_gemini_commit_message "${1:-display}"
fi