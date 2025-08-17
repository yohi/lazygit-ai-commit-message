#!/bin/bash
# AI Commit Generator - 自動ウィンドウ起動機能のテストスクリプト

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_mode() {
    echo -e "${PURPLE}[MODE]${NC} $1"
}

# テスト用のファイル変更を作成
setup_test_environment() {
    log_info "🔧 テスト環境を準備中..."
    
    # テストファイルを作成
    local test_content="Auto Window Test File - $(date)"
    echo "$test_content" > test_auto_window.txt
    echo "機能: 自動ウィンドウ起動" >> test_auto_window.txt
    echo "日時: $(date)" >> test_auto_window.txt
    echo "モード: 各種自動実行テスト" >> test_auto_window.txt
    
    # Gitにファイルを追加
    if git add test_auto_window.txt; then
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
    rm -f test_auto_window.txt
    
    # Gitのステージからも削除
    git reset HEAD test_auto_window.txt 2>/dev/null || true
    
    log_info "✅ クリーンアップ完了"
}

# スマートモードのテスト
test_smart_mode() {
    log_test "🚀 スマートモード（--smart-mode）のテスト"
    log_mode "AI生成→自動ウィンドウ→コミット実行"
    
    echo "📝 スマートモードをテストします"
    echo "⚠️  注意: 実際にコミットが実行されます"
    
    local proceed
    read -p "続行しますか？ (y/N): " proceed
    
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
        log_info "スマートモードを実行中..."
        if "${PROJECT_DIR}/ai-commit-generator" --smart-mode; then
            log_info "✅ スマートモードテスト成功"
            return 0
        else
            log_warn "⚠️  スマートモードがキャンセルまたは失敗しました"
            return 1
        fi
    else
        log_info "スマートモードテストをスキップしました"
        return 0
    fi
}

# 自動ウィンドウモードのテスト
test_auto_window_mode() {
    log_test "🖥️  自動ウィンドウモード（--auto-window）のテスト"
    log_mode "AI生成→自動ウィンドウ起動"
    
    echo "📝 自動ウィンドウモードをテストします"
    echo "💡 ウィンドウが自動で開くかテストします"
    
    local proceed
    read -p "続行しますか？ (y/N): " proceed
    
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
        log_info "自動ウィンドウモードを実行中..."
        if "${PROJECT_DIR}/ai-commit-generator" --auto-window; then
            log_info "✅ 自動ウィンドウモードテスト成功"
            return 0
        else
            log_warn "⚠️  自動ウィンドウモードがキャンセルまたは失敗しました"
            return 1
        fi
    else
        log_info "自動ウィンドウモードテストをスキップしました"
        return 0
    fi
}

# Lazygit統合自動ウィンドウモードのテスト
test_lazygit_auto_window() {
    log_test "🔄 Lazygit統合自動ウィンドウモード（--auto-window --lazygit-mode）のテスト"
    log_mode "AI生成→Lazygitログ表示→別プロセスで自動ウィンドウ"
    
    echo "📝 Lazygit統合自動ウィンドウモードをテストします"
    echo "💡 生成完了後、別プロセスで自動ウィンドウが起動します"
    
    local proceed
    read -p "続行しますか？ (y/N): " proceed
    
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
        log_info "Lazygit統合自動ウィンドウモードを実行中..."
        if "${PROJECT_DIR}/ai-commit-generator" --auto-window --lazygit-mode; then
            log_info "✅ AI生成完了（別プロセスで自動ウィンドウ起動中）"
            log_info "💡 約2秒後に自動ウィンドウが起動します"
            
            # プロセス確認
            sleep 3
            if pgrep -f "ai-commit-generator.*custom-window-with-message" >/dev/null; then
                log_info "✅ 自動ウィンドウプロセスが起動中です"
            else
                log_warn "⚠️  自動ウィンドウプロセスが見つかりません"
            fi
            
            return 0
        else
            log_warn "⚠️  Lazygit統合モードが失敗しました"
            return 1
        fi
    else
        log_info "Lazygit統合自動ウィンドウモードテストをスキップしました"
        return 0
    fi
}

# フォールバック機能のテスト
test_fallback_functionality() {
    log_test "🔧 フォールバック機能のテスト"
    
    # dialog/whiptail/nanoが利用できない環境をシミュレート
    local original_path="$PATH"
    export PATH="/bin:/usr/bin"  # 限定されたPATH
    
    log_info "限定された環境でフォールバック機能をテスト中..."
    
    # AI生成のみテスト
    local ai_message
    if ai_message=$("${PROJECT_DIR}/ai-commit-generator" --generate-only 2>/dev/null); then
        log_info "✅ AI生成成功: $ai_message"
        
        # フォールバック編集テスト
        echo "📝 フォールバック編集機能をテストします"
        echo "💡 シンプル編集モードが起動します"
        
        if echo "$ai_message" | "${PROJECT_DIR}/src/commit_window.sh" --demo; then
            log_info "✅ フォールバック機能テスト成功"
        else
            log_warn "⚠️  フォールバック機能テストがキャンセルされました"
        fi
    else
        log_error "❌ AI生成に失敗しました"
    fi
    
    # PATH復元
    export PATH="$original_path"
}

# 依存関係をチェック
check_dependencies() {
    log_info "🔍 依存関係をチェック中..."
    
    local missing_deps=()
    local available_editors=()
    
    # 必須コマンドをチェック
    local required_commands=("git" "bash")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # エディターをチェック
    local editor_commands=("dialog" "whiptail" "nano" "vi")
    for cmd in "${editor_commands[@]}"; do
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
        log_warn "⚠️  推奨エディターが見つかりません。フォールバック機能のみ利用可能です"
    fi
    
    return 0
}

# 環境情報を表示
show_environment_info() {
    log_info "📋 自動ウィンドウ機能テスト環境情報"
    echo "  プロジェクトディレクトリ: $PROJECT_DIR"
    echo "  Git リポジトリ: $(git rev-parse --show-toplevel 2>/dev/null || echo 'Not in git repo')"
    echo "  現在のブランチ: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
    echo "  利用可能なモード:"
    echo "    --smart-mode: AI生成→自動ウィンドウ→コミット"
    echo "    --auto-window: AI生成→自動ウィンドウ起動"
    echo "    --auto-window --lazygit-mode: Lazygit統合自動ウィンドウ"
    echo
}

# 使用方法を表示
show_usage() {
    cat <<EOF
🧪 AI Commit Generator - 自動ウィンドウ機能テスト

使用方法: $0 [オプション]

オプション:
  --smart-mode     スマートモードのテスト
  --auto-window    自動ウィンドウモードのテスト
  --lazygit-auto   Lazygit統合自動ウィンドウのテスト
  --fallback       フォールバック機能のテスト
  --all           すべてのテストを実行
  -h, --help      このヘルプを表示

例:
  $0 --all                    # 全テスト実行
  $0 --smart-mode            # スマートモードのみテスト
  $0 --auto-window           # 自動ウィンドウモードのみテスト

注意:
  - 一部のテストは実際にコミットを実行します
  - テスト前に作業内容をバックアップしてください
EOF
}

# メイン実行関数
main() {
    local run_smart=false
    local run_auto=false
    local run_lazygit=false
    local run_fallback=false
    local run_all=false
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --smart-mode)
                run_smart=true
                shift
                ;;
            --auto-window)
                run_auto=true
                shift
                ;;
            --lazygit-auto)
                run_lazygit=true
                shift
                ;;
            --fallback)
                run_fallback=true
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "エラー: 不明なオプション: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    # デフォルトで全テスト実行
    if [[ "$run_smart" == "false" && "$run_auto" == "false" && "$run_lazygit" == "false" && "$run_fallback" == "false" && "$run_all" == "false" ]]; then
        run_all=true
    fi
    
    echo "🧪 AI Commit Generator - 自動ウィンドウ機能テスト"
    echo "==============================================="
    
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
    
    local test_results=()
    
    # テスト実行
    if [[ "$run_all" == "true" || "$run_smart" == "true" ]]; then
        echo
        if test_smart_mode; then
            test_results+=("✅ スマートモード")
        else
            test_results+=("⚠️  スマートモード")
        fi
        setup_test_environment  # 再セットアップ
    fi
    
    if [[ "$run_all" == "true" || "$run_auto" == "true" ]]; then
        echo
        if test_auto_window_mode; then
            test_results+=("✅ 自動ウィンドウモード")
        else
            test_results+=("⚠️  自動ウィンドウモード")
        fi
        setup_test_environment  # 再セットアップ
    fi
    
    if [[ "$run_all" == "true" || "$run_lazygit" == "true" ]]; then
        echo
        if test_lazygit_auto_window; then
            test_results+=("✅ Lazygit統合自動ウィンドウ")
        else
            test_results+=("⚠️  Lazygit統合自動ウィンドウ")
        fi
        setup_test_environment  # 再セットアップ
    fi
    
    if [[ "$run_all" == "true" || "$run_fallback" == "true" ]]; then
        echo
        if test_fallback_functionality; then
            test_results+=("✅ フォールバック機能")
        else
            test_results+=("⚠️  フォールバック機能")
        fi
    fi
    
    # 結果表示
    echo
    echo "🎯 テスト結果まとめ"
    echo "=================="
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    echo
    echo "📖 使用方法:"
    echo "  Lazygit内:"
    echo "    Ctrl+S: スマートモード（推奨）"
    echo "    Ctrl+W: カスタムウィンドウ"
    echo "    Alt+W:  自動ウィンドウ（Lazygit統合）"
    echo
    echo "  コマンドライン:"
    echo "    ai-commit-generator --smart-mode"
    echo "    ai-commit-generator --auto-window"
    echo "    ai-commit-generator --custom-window"
    
    log_info "🎉 自動ウィンドウ機能テストが完了しました！"
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi