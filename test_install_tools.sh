#!/bin/bash
# キー送信ツールのインストールテスト用スクリプト

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 環境情報表示
show_environment() {
    log_info "=== 環境情報 ==="
    echo "OS: $(uname -a)"
    echo "Session Type: ${XDG_SESSION_TYPE:-unknown}"
    echo "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Display: ${DISPLAY:-unset}"
    echo "Wayland Display: ${WAYLAND_DISPLAY:-unset}"
    echo "TMUX: ${TMUX:-unset}"
    echo ""
}

# 現在のツール状況確認
check_current_tools() {
    log_info "=== 現在のキー送信ツール状況 ==="
    
    echo "tmux: $(command -v tmux >/dev/null 2>&1 && echo "✓ インストール済み" || echo "✗ 未インストール")"
    echo "xdotool: $(command -v xdotool >/dev/null 2>&1 && echo "✓ インストール済み" || echo "✗ 未インストール")"
    echo "ydotool: $(command -v ydotool >/dev/null 2>&1 && echo "✓ インストール済み" || echo "✗ 未インストール")"
    
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v ydotool >/dev/null 2>&1; then
        echo "ydotoolサービス: $(systemctl is-active --quiet ydotool 2>/dev/null && echo "✓ 実行中" || echo "✗ 停止中")"
    fi
    echo ""
}

# インストールテスト実行
test_install() {
    log_info "=== キー送信ツールインストールテスト開始 ==="
    
    # install.shの該当関数を一時的にソース
    source "${SCRIPT_DIR}/scripts/install.sh"
    
    # 関数を実行
    if install_key_sending_tools; then
        log_success "キー送信ツールのインストールが完了しました"
    else
        log_error "キー送信ツールのインストールに失敗しました"
        return 1
    fi
}

# インストール後確認
verify_installation() {
    log_info "=== インストール後確認 ==="
    
    local success=true
    
    # 基本ツール確認
    if ! command -v tmux >/dev/null 2>&1; then
        log_warn "tmuxがインストールされていません"
        success=false
    fi
    
    # 環境別確認
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        if command -v ydotool >/dev/null 2>&1; then
            log_success "Wayland環境: ydotool利用可能"
            if systemctl is-active --quiet ydotool 2>/dev/null; then
                log_success "ydotoolサービス実行中"
            else
                log_warn "ydotoolサービスが停止中（手動で有効化: sudo systemctl enable --now ydotool）"
            fi
        else
            log_error "Wayland環境でydotoolが利用不可"
            success=false
        fi
    else
        if command -v xdotool >/dev/null 2>&1; then
            log_success "X11環境: xdotool利用可能"
        else
            log_error "X11環境でxdotoolが利用不可"
            success=false
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        log_success "すべてのキー送信ツールが正常にインストールされました"
    else
        log_error "一部のキー送信ツールに問題があります"
        return 1
    fi
}

# メイン実行
main() {
    echo "キー送信ツールインストールテスト"
    echo "=================================="
    echo ""
    
    show_environment
    check_current_tools
    
    # ユーザー確認
    read -p "キー送信ツールのインストールを実行しますか？ [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "インストールをキャンセルしました"
        exit 0
    fi
    
    test_install
    echo ""
    verify_installation
    
    log_success "インストールテスト完了"
}

main "$@"