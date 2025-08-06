#!/bin/bash

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

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

check_dependencies() {
    local missing_deps=()
    
    show_info "依存関係をチェックしています..."
    
    command -v git >/dev/null 2>&1 || missing_deps+=(git)
    command -v gemini >/dev/null 2>&1 || missing_deps+=(gemini)
    
    # yq v4以上を要求
    if ! command -v yq >/dev/null 2>&1; then
        missing_deps+=(yq)
    else
        local yq_version
        yq_version=$(yq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | cut -d'v' -f2 | cut -d'.' -f1)
        if [ -z "$yq_version" ] || [ "$yq_version" -lt 4 ]; then
            show_error "yq バージョン4以上が必要です（現在: $(yq --version 2>/dev/null || echo '不明')）"
            missing_deps+=(yq-v4)
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        show_error "以下の依存関係が不足しています:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                git)
                    echo "  - git: sudo apt install git (Ubuntu/Debian) または brew install git (macOS)"
                    ;;
                yq)
                    echo "  - yq v4+: 以下の方法でインストールしてください"
                    echo "    Ubuntu/Debian: sudo snap install yq"
                    echo "    macOS: brew install yq"
                    echo "    または https://github.com/mikefarah/yq#install からダウンロード"
                    ;;
                yq-v4)
                    echo "  - yq v4+: 現在のバージョンが古すぎます"
                    echo "    Ubuntu/Debian: sudo snap install yq (または古いものをアンインストール)"
                    echo "    macOS: brew upgrade yq"
                    echo "    または https://github.com/mikefarah/yq#install からダウンロード"
                    ;;
                gemini)
                    echo "  - gemini: https://github.com/google/gemini-cli からインストールしてください"
                    ;;
            esac
        done
        echo ""
        show_error "必要な依存関係をインストール後、再度実行してください"
        return 1
    fi
    
    show_success "依存関係チェック完了"
    return 0
}

backup_existing_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        show_info "既存の設定ファイルをバックアップしました: $backup_file"
    fi
}

install_files() {
    show_info "ファイルをインストールしています..."
    
    mkdir -p "$SCRIPTS_DIR"
    
    cp "$SCRIPT_DIR/gemini-commit.sh" "$SCRIPTS_DIR/"
    chmod +x "$SCRIPTS_DIR/gemini-commit.sh"
    
    cp -r "$SCRIPT_DIR/lib" "$SCRIPTS_DIR/"
    
    if [ -f "$SCRIPT_DIR/config/gemini-commit.yml" ] && [ ! -f "$PLUGIN_CONFIG_FILE" ]; then
        cp "$SCRIPT_DIR/config/gemini-commit.yml" "$PLUGIN_CONFIG_FILE"
        show_info "プラグイン設定ファイルをインストールしました: $PLUGIN_CONFIG_FILE"
    fi
    
    show_success "ファイルインストール完了"
}

update_lazygit_config() {
    show_info "Lazygit設定を更新しています..."
    
    local temp_config
    temp_config=$(mktemp)
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$temp_config"
    else
        echo "customCommands: []" > "$temp_config"
    fi
    
    local existing_command
    if existing_command=$(yq eval '.customCommands[] | select(.command | contains("gemini-commit.sh"))' "$temp_config" 2>/dev/null) && [ -n "$existing_command" ]; then
        show_info "既存のGeminiCLIコマンド設定が見つかりました"
        show_info "設定を更新します..."
        
        yq eval 'del(.customCommands[] | select(.command | contains("gemini-commit.sh")))' -i "$temp_config"
    fi
    
    yq eval '.customCommands += [{
        "key": "<c-g>",
        "context": "files",
        "description": "AI コミットメッセージ生成",
        "command": "'"$SCRIPTS_DIR/gemini-commit.sh"'",
        "subprocess": true,
        "prompts": [{
            "type": "confirm",
            "title": "生成AIがコミットメッセージを作成します。よろしいですか？",
            "body": "ステージングされた変更を分析してコミットメッセージを生成します。"
        }]
    }]' "$temp_config" > "$CONFIG_FILE"
    
    rm -f "$temp_config"
    
    show_success "Lazygit設定更新完了"
}

show_installation_complete() {
    echo ""
    echo "=================================================="
    echo "🎉 Lazygit GeminiCLI プラグインインストール完了！"
    echo "=================================================="
    echo ""
    echo "使用方法:"
    echo "1. Lazygitを起動します"
    echo "2. ファイルをステージング (スペースキー) します"
    echo "3. ファイルペインで Ctrl+G を押します"
    echo "4. 確認ダイアログで Enter を押します"
    echo "5. AIが生成したコミットメッセージを確認・編集します"
    echo ""
    echo "設定ファイル:"
    echo "  - プラグイン設定: $PLUGIN_CONFIG_FILE"
    echo "  - Lazygit設定: $CONFIG_FILE"
    echo ""
    echo "トラブルシューティング:"
    echo "  - 依存関係チェック: $SCRIPTS_DIR/gemini-commit.sh --check-deps"
    echo "  - 設定表示: $SCRIPTS_DIR/gemini-commit.sh --config"
    echo "  - ヘルプ: $SCRIPTS_DIR/gemini-commit.sh --help"
    echo ""
    echo "詳細については README.md を参照してください。"
    echo "=================================================="
}

show_usage() {
    cat << EOF
使用方法: $SCRIPT_NAME [オプション]

Lazygit GeminiCLI プラグインをインストールします。

オプション:
    -h, --help          このヘルプを表示
    --check-only        依存関係チェックのみ実行
    --force             既存ファイルを強制上書き

例:
    $SCRIPT_NAME                インストール実行
    $SCRIPT_NAME --check-only   依存関係チェックのみ
    $SCRIPT_NAME --force        強制インストール
EOF
}

main() {
    local check_only=false
    local force_install=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                return 0
                ;;
            --check-only)
                check_only=true
                ;;
            --force)
                force_install=true
                ;;
            *)
                show_error "不明なオプション: $1"
                show_usage
                return 1
                ;;
        esac
        shift
    done
    
    echo "Lazygit GeminiCLI プラグインインストーラー v1.0.0"
    echo ""
    
    if ! check_dependencies; then
        return 1
    fi
    
    if [ "$check_only" = true ]; then
        show_info "依存関係チェックのみを実行しました"
        return 0
    fi
    
    if [ "$force_install" = false ]; then
        if [ -f "$SCRIPTS_DIR/gemini-commit.sh" ]; then
            echo -n "既存のインストールが見つかりました。上書きしますか？ [y/N]: "
            read -r response
            case "$response" in
                [yY]|[yY][eE][sS])
                    ;;
                *)
                    show_info "インストールをキャンセルしました"
                    return 0
                    ;;
            esac
        fi
    fi
    
    backup_existing_config
    install_files
    update_lazygit_config
    show_installation_complete
    
    return 0
}

main "$@"