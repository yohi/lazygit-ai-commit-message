#!/bin/bash

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly INSTALL_DIR="$HOME/.config/lazygit"
readonly SCRIPTS_DIR="$INSTALL_DIR/scripts"
readonly CONFIG_FILE="$INSTALL_DIR/config.yml"
readonly PLUGIN_CONFIG_FILE="$INSTALL_DIR/gemini-commit.yml"

show_error() {
    echo "❌ エラー: $1" >&2
}

show_warning() {
    echo "⚠️  警告: $1" >&2
}

show_info() {
    echo "ℹ️  情報: $1" >&2
}

show_success() {
    echo "✅ 成功: $1" >&2
}

backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local backup_file="${CONFIG_FILE}.uninstall_backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        show_info "設定ファイルをバックアップしました: $backup_file"
    fi
}

remove_files() {
    show_info "プラグインファイルを削除しています..."
    
    if [ -f "$SCRIPTS_DIR/gemini-commit.sh" ]; then
        rm -f "$SCRIPTS_DIR/gemini-commit.sh"
        show_info "メインスクリプトを削除しました"
    fi
    
    if [ -d "$SCRIPTS_DIR/lib" ]; then
        rm -rf "$SCRIPTS_DIR/lib"
        show_info "ライブラリディレクトリを削除しました"
    fi
    
    if [ -f "$PLUGIN_CONFIG_FILE" ]; then
        echo -n "プラグイン設定ファイルも削除しますか？ [y/N]: "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                rm -f "$PLUGIN_CONFIG_FILE"
                show_info "プラグイン設定ファイルを削除しました"
                ;;
            *)
                show_info "プラグイン設定ファイルは保持されます: $PLUGIN_CONFIG_FILE"
                ;;
        esac
    fi
    
    show_success "ファイル削除完了"
}

update_lazygit_config() {
    show_info "Lazygit設定からプラグインを削除しています..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        show_info "Lazygit設定ファイルが見つかりません"
        return 0
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        show_warning "yqコマンドが見つかりません"
        show_info "手動でLazygit設定からgemini-commit.shコマンドを削除してください"
        return 0
    fi
    
    local temp_config
    temp_config=$(mktemp)
    cp "$CONFIG_FILE" "$temp_config"
    
    if yq eval '.customCommands[] | select(.command | contains("gemini-commit.sh"))' "$temp_config" >/dev/null 2>&1; then
        yq eval 'del(.customCommands[] | select(.command | contains("gemini-commit.sh")))' "$temp_config" > "$CONFIG_FILE"
        show_info "Lazygit設定からプラグインコマンドを削除しました"
    else
        show_info "Lazygit設定にプラグインコマンドが見つかりませんでした"
    fi
    
    rm -f "$temp_config"
    show_success "Lazygit設定更新完了"
}

show_uninstallation_complete() {
    echo ""
    echo "=================================================="
    echo "🗑️  Lazygit GeminiCLI プラグインアンインストール完了"
    echo "=================================================="
    echo ""
    echo "削除されたファイル:"
    echo "  - $SCRIPTS_DIR/gemini-commit.sh"
    echo "  - $SCRIPTS_DIR/lib/ (ライブラリディレクトリ)"
    echo ""
    echo "保持されたファイル:"
    if [ -f "$PLUGIN_CONFIG_FILE" ]; then
        echo "  - $PLUGIN_CONFIG_FILE (プラグイン設定)"
    fi
    echo "  - 設定バックアップファイル (*.backup.*, *.uninstall_backup.*)"
    echo ""
    echo "完全にクリーンアップする場合:"
    echo "  rm -f \"$PLUGIN_CONFIG_FILE\""
    echo "  rm -f \"$INSTALL_DIR\"/config.yml.*backup.*"
    echo ""
    echo "プラグインのアンインストールが完了しました。"
    echo "Lazygitを再起動してください。"
    echo "=================================================="
}

show_usage() {
    cat << EOF
使用方法: $SCRIPT_NAME [オプション]

Lazygit GeminiCLI プラグインをアンインストールします。

オプション:
    -h, --help          このヘルプを表示
    --keep-config       プラグイン設定ファイルを保持
    --force             確認なしで実行

例:
    $SCRIPT_NAME                通常のアンインストール
    $SCRIPT_NAME --keep-config  設定ファイルを保持
    $SCRIPT_NAME --force        確認なしで実行
EOF
}

main() {
    local keep_config=false
    local force_uninstall=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                return 0
                ;;
            --keep-config)
                keep_config=true
                ;;
            --force)
                force_uninstall=true
                ;;
            *)
                show_error "不明なオプション: $1"
                show_usage
                return 1
                ;;
        esac
        shift
    done
    
    echo "Lazygit GeminiCLI プラグインアンインストーラー v1.0.0"
    echo ""
    
    if [ ! -f "$SCRIPTS_DIR/gemini-commit.sh" ] && [ ! -d "$SCRIPTS_DIR/lib" ]; then
        show_info "プラグインがインストールされていないようです"
        return 0
    fi
    
    if [ "$force_uninstall" = false ]; then
        echo -n "Lazygit GeminiCLI プラグインをアンインストールしますか？ [y/N]: "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                ;;
            *)
                show_info "アンインストールをキャンセルしました"
                return 0
                ;;
        esac
    fi
    
    backup_config
    
    if [ "$keep_config" = false ]; then
        remove_files
    else
        show_info "設定ファイル保持モードでファイルを削除しています..."
        
        if [ -f "$SCRIPTS_DIR/gemini-commit.sh" ]; then
            rm -f "$SCRIPTS_DIR/gemini-commit.sh"
        fi
        
        if [ -d "$SCRIPTS_DIR/lib" ]; then
            rm -rf "$SCRIPTS_DIR/lib"
        fi
        
        show_info "プラグイン設定ファイルは保持されます: $PLUGIN_CONFIG_FILE"
        show_success "ファイル削除完了（設定保持）"
    fi
    
    update_lazygit_config
    show_uninstallation_complete
    
    return 0
}

main "$@"