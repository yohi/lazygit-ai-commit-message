#!/bin/bash
# AI Commit Generator - カスタムウィンドウ機能のテストスクリプト

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# テスト用のファイル変更を作成
setup_test_environment() {
    log_info "🔧 テスト環境を準備中..."
    
    # テストファイルを作成
    echo "テスト用のファイル内容" > test_custom_window.txt
    echo "追加のテスト行" >> test_custom_window.txt
    
    # Gitにファイルを追加
    if git add test_custom_window.txt; then
        log_info "✅ テストファイルをステージに追加しました"
    else
        log_error "❌ テストファイルの追加に失敗しました"
        return 1
    fi
    
    log_info "📊 現在のステージ状況:"
    git status --short
}

# テスト環境をクリーンアップ
cleanup_test_environment() {
    log_info "🧹 テスト環境をクリーンアップ中..."
    
    # テストファイルを削除
    rm -f test_custom_window.txt
    
    # Gitのステージからも削除
    git reset HEAD test_custom_window.txt 2>/dev/null || true
    
    log_info "✅ クリーンアップ完了"
}

# カスタムウィンドウ機能をテスト
test_custom_window() {
    log_test "🖥️  カスタムウィンドウ機能のテスト開始"
    
    # AI生成のみモードをテスト
    log_test "1️⃣  生成のみモードのテスト"
    local generated_message
    if generated_message=$("${PROJECT_DIR}/ai-commit-generator" --generate-only 2>/dev/null); then
        log_info "✅ メッセージ生成成功: $generated_message"
    else
        log_error "❌ メッセージ生成に失敗しました"
        return 1
    fi
    
    # commit_window.shのテスト
    log_test "2️⃣  コミットウィンドウモジュールのテスト"
    if source "${PROJECT_DIR}/src/commit_window.sh"; then
        log_info "✅ commit_window.sh の読み込み成功"
    else
        log_error "❌ commit_window.sh の読み込みに失敗しました"
        return 1
    fi
    
    # デモメッセージでウィンドウテスト
    log_test "3️⃣  デモウィンドウの表示テスト"
    echo "📝 デモ用のコミットメッセージでウィンドウをテストします..."
    echo "注意: ウィンドウが表示されたら適切に編集・確認してください"
    
    local demo_message="feat: Add custom commit window functionality

- Implement TUI-based commit message editor
- Support multiple editor backends (dialog, whiptail, nano)
- Add confirmation dialogs
- Include proper error handling and cleanup

This commit demonstrates the new custom window feature
for AI-generated commit messages."
    
    # デモ実行
    if "${PROJECT_DIR}/src/commit_window.sh" --demo; then
        log_info "✅ デモウィンドウテスト成功"
    else
        log_warn "⚠️  デモウィンドウがキャンセルされました（正常）"
    fi
}

# 依存関係をチェック
check_dependencies() {
    log_info "🔍 依存関係をチェック中..."
    
    local missing_deps=()
    
    # 必須コマンドをチェック
    local required_commands=("git" "tput")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # オプションコマンドをチェック
    local optional_commands=("dialog" "whiptail" "nano")
    local available_editors=()
    
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            available_editors+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "❌ 必須の依存関係が不足しています: ${missing_deps[*]}"
        return 1
    fi
    
    log_info "✅ 必須依存関係: OK"
    
    if [[ ${#available_editors[@]} -gt 0 ]]; then
        log_info "✅ 利用可能なエディター: ${available_editors[*]}"
    else
        log_warn "⚠️  推奨エディターが見つかりません。基本機能のみ利用可能です"
    fi
    
    return 0
}

# 環境情報を表示
show_environment_info() {
    log_info "📋 環境情報"
    echo "  プロジェクトディレクトリ: $PROJECT_DIR"
    echo "  Git リポジトリ: $(git rev-parse --show-toplevel 2>/dev/null || echo 'Not in git repo')"
    echo "  現在のブランチ: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
    echo "  ターミナルサイズ: $(tput cols 2>/dev/null || echo 'Unknown')x$(tput lines 2>/dev/null || echo 'Unknown')"
    echo "  シェル: ${SHELL:-Unknown}"
    echo
}

# メイン実行関数
main() {
    echo "🧪 AI Commit Generator - カスタムウィンドウ機能テスト"
    echo "=================================================="
    
    # 環境情報表示
    show_environment_info
    
    # 依存関係チェック
    if ! check_dependencies; then
        log_error "❌ 依存関係チェックに失敗しました"
        exit 1
    fi
    
    # Gitリポジトリチェック
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "❌ Gitリポジトリ内で実行してください"
        exit 1
    fi
    
    # エラーハンドラー設定
    trap cleanup_test_environment EXIT
    trap cleanup_test_environment SIGINT
    trap cleanup_test_environment SIGTERM
    
    # テスト環境セットアップ
    if ! setup_test_environment; then
        log_error "❌ テスト環境のセットアップに失敗しました"
        exit 1
    fi
    
    # カスタムウィンドウ機能テスト
    if test_custom_window; then
        log_info "🎉 すべてのテストが完了しました！"
        
        echo
        echo "📖 使用方法:"
        echo "  1. Lazygit内で Ctrl+W を押してカスタムウィンドウモードを起動"
        echo "  2. または直接コマンド実行: ai-commit-generator --custom-window"
        echo "  3. 生成のみ: ai-commit-generator --generate-only"
        
    else
        log_error "❌ テストに失敗しました"
        exit 1
    fi
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi