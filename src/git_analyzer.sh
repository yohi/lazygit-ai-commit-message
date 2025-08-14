#!/bin/bash
# Git diff分析スクリプト

# エラーハンドリング
set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# ステージされたファイルが存在するかチェック
check_staged_files() {
    log_debug "ステージされたファイルをチェック中..."
    
    if ! git diff --cached --name-only | head -1 | grep -q .; then
        log_error "ステージされたファイルがありません"
        echo "ファイルをステージしてからコミットメッセージを生成してください。" >&2
        return 1
    fi
    
    log_info "ステージされたファイルが見つかりました"
    return 0
}

# Git diffを取得
get_git_diff() {
    log_debug "Git diffを取得中..."
    
    local diff_output
    diff_output=$(git diff --cached)
    
    if [[ -z "$diff_output" ]]; then
        log_error "空のdiffです"
        return 1
    fi
    
    echo "$diff_output"
    return 0
}

# ファイル情報を分析
analyze_files() {
    log_debug "ファイル分析を開始..."
    
    local files_json=""
    local total_files=0
    local total_additions=0
    local total_deletions=0
    
    # ステージされたファイルの統計を取得
    while IFS=$'\t' read -r additions deletions filename; do
        # 数値でない場合はスキップ（バイナリファイルなど）
        if [[ "$additions" =~ ^[0-9]+$ ]] && [[ "$deletions" =~ ^[0-9]+$ ]]; then
            total_additions=$((total_additions + additions))
            total_deletions=$((total_deletions + deletions))
        fi
        
        # ファイルタイプを推定
        local file_type="unknown"
        case "${filename##*.}" in
            js|jsx|ts|tsx) file_type="javascript" ;;
            py) file_type="python" ;;
            java) file_type="java" ;;
            c|cpp|cc|cxx) file_type="c++" ;;
            h|hpp) file_type="header" ;;
            sh|bash) file_type="shell" ;;
            yml|yaml) file_type="yaml" ;;
            json) file_type="json" ;;
            md) file_type="markdown" ;;
            html) file_type="html" ;;
            css) file_type="css" ;;
            *) file_type="text" ;;
        esac
        
        # 変更タイプを判定
        local change_type="modified"
        if git diff --cached --name-status | grep -q "^A.*${filename}$"; then
            change_type="added"
        elif git diff --cached --name-status | grep -q "^D.*${filename}$"; then
            change_type="deleted"
        elif git diff --cached --name-status | grep -q "^R.*${filename}$"; then
            change_type="renamed"
        fi
        
        # JSONエントリを構築（数値の安全な処理）
        local safe_additions="${additions//[^0-9]/}"
        local safe_deletions="${deletions//[^0-9]/}"
        safe_additions="${safe_additions:-0}"
        safe_deletions="${safe_deletions:-0}"
        
        local file_entry=$(cat <<EOF
    {
      "path": "${filename}",
      "type": "${change_type}",
      "additions": ${safe_additions},
      "deletions": ${safe_deletions},
      "language": "${file_type}"
    }
EOF
        )
        
        if [[ -n "$files_json" ]]; then
            files_json="${files_json},"
        fi
        files_json="${files_json}${file_entry}"
        
        total_files=$((total_files + 1))
        
    done < <(git diff --cached --numstat)
    
    # 変更タイプを推定
    local change_types=""
    if [[ $total_additions -gt $total_deletions ]]; then
        if git diff --cached --name-status | grep -q "^A"; then
            change_types="\"feature\""
        else
            change_types="\"enhancement\""
        fi
    elif [[ $total_deletions -gt $total_additions ]]; then
        change_types="\"cleanup\""
    else
        change_types="\"refactor\""
    fi
    
    # JSONを出力
    cat <<EOF
{
  "files": [
${files_json}
  ],
  "summary": {
    "total_files": ${total_files},
    "total_additions": ${total_additions},
    "total_deletions": ${total_deletions},
    "change_types": [${change_types}]
  }
}
EOF
    
    log_info "ファイル分析完了: ${total_files}ファイル, +${total_additions}/-${total_deletions}"
}

# メイン関数
main() {
    log_info "Git diff分析を開始..."
    
    # Gitリポジトリチェック
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Gitリポジトリではありません"
        echo "Gitリポジトリ内で実行してください。" >&2
        return 1
    fi
    
    # ステージされたファイルをチェック
    if ! check_staged_files; then
        return 1
    fi
    
    # ファイル分析を実行
    analyze_files
    
    log_info "Git diff分析完了"
    return 0
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi