#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

check_dependencies() {
    local missing_deps=()
    local warnings=()
    
    log_debug "依存関係チェックを開始します"
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    else
        log_debug "git: $(git --version)"
    fi
    
    if ! command -v gemini >/dev/null 2>&1; then
        missing_deps+=("gemini")
    else
        log_debug "gemini: 利用可能"
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        warnings+=("yq (設定ファイル読み込みに使用)")
    else
        local yq_version
        yq_version=$(yq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | cut -d'v' -f2 | cut -d'.' -f1)
        if [ -z "$yq_version" ] || [ "$yq_version" -lt 4 ]; then
            warnings+=("yq v4+ (現在のバージョンが古すぎます: $(yq --version 2>/dev/null))")
        else
            log_debug "yq: $(yq --version 2>/dev/null)"
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        show_error "必要な依存関係が見つかりません:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "インストール方法:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "git")
                    echo "  - git: sudo apt install git (Ubuntu/Debian) または brew install git (macOS)"
                    ;;
                "gemini")
                    echo "  - gemini: 公式ドキュメントに従ってインストールしてください"
                    echo "    https://github.com/google/gemini-cli"
                    ;;
                "yq")
                    echo "  - yq: sudo apt install yq (Ubuntu/Debian) または brew install yq (macOS)"
                    ;;
            esac
        done
        return $ERROR_DEPENDENCY
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        show_warning "推奨依存関係が見つかりません (動作には影響しません):"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    log_debug "依存関係チェック完了"
    return $ERROR_SUCCESS
}

check_git_repository() {
    if ! is_git_repository; then
        show_error "現在のディレクトリはGitリポジトリではありません"
        return $ERROR_GENERAL
    fi
    
    log_debug "Gitリポジトリを確認しました: $(get_git_root)"
    return $ERROR_SUCCESS
}

check_gemini_api_access() {
    local test_prompt="Hello"
    local temp_output
    temp_output=$(create_secure_temp_file)
    
    log_debug "GeminiCLI APIアクセステストを実行します"
    
    if timeout 10 gemini \
        --model "$GEMINI_MODEL" \
        --prompt "$test_prompt" \
        > "$temp_output" 2>/dev/null; then
        
        log_debug "GeminiCLI APIアクセステスト成功"
        rm -f "$temp_output"
        return $ERROR_SUCCESS
    else
        show_error "GeminiCLI APIへのアクセスに失敗しました"
        show_info "API キーが正しく設定されているか確認してください"
        rm -f "$temp_output"
        return $ERROR_GEMINI_API
    fi
}