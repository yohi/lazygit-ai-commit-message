#!/bin/bash
# AI Commit Generator インストールスクリプト

set -euo pipefail

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

# インストール先ディレクトリ
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/ai-commit-generator"
LAZYGIT_CONFIG_DIR="${HOME}/.config/lazygit"

# スクリプトのディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 使用方法を表示
show_usage() {
    cat <<EOF
AI Commit Generator インストールスクリプト

使用方法:
  ./install.sh [オプション]

オプション:
  -h, --help              このヘルプを表示
  -u, --uninstall         アンインストール
  -f, --force             強制上書きインストール
  --install-dir <dir>     インストール先ディレクトリ (デフォルト: ~/.local/bin)
  --skip-lazygit-config   Lazygit設定の更新をスキップ

例:
  ./install.sh                    # 標準インストール
  ./install.sh --force            # 強制上書きインストール
  ./install.sh --uninstall        # アンインストール
EOF
}

# 依存関係チェック
check_dependencies() {
    log_info "依存関係をチェック中..."

    local missing_deps=()

    # 必須依存関係
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi

    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    # yq v4の確認
    if ! command -v yq >/dev/null 2>&1; then
        missing_deps+=("yq v4 (mikefarah/yq)")
    elif ! yq --version 2>/dev/null | grep -q "version v4\|mikefarah"; then
        missing_deps+=("yq v4 (現在: $(yq --version 2>/dev/null | head -1), 必要: yq v4.x mikefarah/yq)")
    fi

    # オプション依存関係
    local optional_deps=()

    if ! command -v gemini >/dev/null 2>&1; then
        optional_deps+=("gemini")
    fi

    # 必須依存関係が不足している場合はエラー
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "以下の必須依存関係がインストールされていません:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        echo "インストール方法:"
        echo "  - jq: brew install jq"
        echo "  - yq v4: brew install yq (mikefarah/yq)"
        echo "  - または: https://github.com/mikefarah/yq/#install"
        echo
        echo "これらをインストールしてから再実行してください。"
        exit 1
    fi

    # オプション依存関係の警告
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warn "以下のオプション依存関係がインストールされていません:"
        for dep in "${optional_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        echo "基本機能は動作しますが、完全な機能を利用するには上記をインストールすることを推奨します。"
        echo
    fi

    log_success "依存関係チェック完了"
}

# ディレクトリを作成
create_directories() {
    log_info "ディレクトリを作成中..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LAZYGIT_CONFIG_DIR"

    log_success "ディレクトリ作成完了"
}

# ファイルをインストール
install_files() {
    log_info "ファイルをインストール中..."

    # メインスクリプトをコピー
    cp "$PROJECT_DIR/ai-commit-generator" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/ai-commit-generator"

    # srcディレクトリをコピー
    cp -r "$PROJECT_DIR/src" "$INSTALL_DIR/"

    # scriptsディレクトリをコピー
    cp -r "$PROJECT_DIR/scripts" "$INSTALL_DIR/"

    # 設定ファイルをコピー（既存設定の保護）
    if [[ -d "$CONFIG_DIR/config" ]]; then
        backup_dir="$CONFIG_DIR/config.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "既存の設定ディレクトリをバックアップ: $backup_dir"
        mv "$CONFIG_DIR/config" "$backup_dir"
        cp -r "$PROJECT_DIR/config" "$CONFIG_DIR/"
        log_info "新しい設定を適用し、既存設定は $backup_dir に保存しました"
    else
        cp -r "$PROJECT_DIR/config" "$CONFIG_DIR/"
    fi

    log_success "ファイルインストール完了"
}

# Lazygit設定を更新
update_lazygit_config() {
    if [[ "${SKIP_LAZYGIT_CONFIG:-false}" == "true" ]]; then
        log_info "Lazygit設定の更新をスキップしました"
        return 0
    fi

    log_info "Lazygit設定を更新中..."

    local lazygit_config="$LAZYGIT_CONFIG_DIR/config.yml"
    local custom_command_config="$PROJECT_DIR/config/lazygit.yml"

    # Lazygit設定ファイルが存在しない場合は作成
    if [[ ! -f "$lazygit_config" ]]; then
        log_info "新しいLazygit設定ファイルを作成します"
        cp "$custom_command_config" "$lazygit_config"
    else
        # 既存の設定ファイルに追加
        log_info "既存のLazygit設定ファイルに追加します"

        # バックアップを作成
        cp "$lazygit_config" "$lazygit_config.backup.$(date +%Y%m%d_%H%M%S)"

        # カスタムコマンドが既に存在するかチェック
        if grep -q "ai-commit-generator" "$lazygit_config" 2>/dev/null; then
            log_warn "AI Commit Generatorのカスタムコマンドは既に設定されています"
        else
            # カスタムコマンドを追加
            if command -v yq >/dev/null 2>&1; then
                # YAMLとして安全にマージ
                log_info "yqを使用してYAML設定をマージします"
                yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$lazygit_config" "$custom_command_config" > "$lazygit_config.tmp" && mv "$lazygit_config.tmp" "$lazygit_config"
            elif grep -q "customCommands:" "$lazygit_config"; then
                # customCommandsセクションが既に存在する場合 - AWKで安全に挿入
                log_info "既存のcustomCommandsセクションに追加します"
                awk '/customCommands:/{print; while((getline line < "'"$custom_command_config"'") > 0) {if(line !~ /^customCommands:/) print line}; next} 1' "$lazygit_config" > "$lazygit_config.tmp" && mv "$lazygit_config.tmp" "$lazygit_config"
            else
                # customCommandsセクションが存在しない場合
                log_info "新しくcustomCommandsセクションを追加します"
                cat "$custom_command_config" >> "$lazygit_config"
            fi
        fi
    fi

    log_success "Lazygit設定更新完了"
}

# PATHの確認と更新
update_path() {
    log_info "PATH設定を確認中..."

    # PATHにINSTALL_DIRが含まれているかチェック
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warn "$INSTALL_DIR がPATHに含まれていません"

        local shell_config=""
        case "$SHELL" in
            */bash)
                shell_config="$HOME/.bashrc"
                ;;
            */zsh)
                shell_config="$HOME/.zshrc"
                ;;
            */fish)
                shell_config="$HOME/.config/fish/config.fish"
                ;;
            *)
                log_warn "不明なシェル: $SHELL"
                ;;
        esac

        if [[ -n "$shell_config" ]]; then
            log_info "以下の行を $shell_config に追加してください:"
            echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        else
            log_info "以下のコマンドを実行してPATHを更新してください:"
            echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
    else
        log_success "PATH設定は正常です"
    fi
}

# インストール完了メッセージ
show_install_complete() {
    log_success "インストールが完了しました！"
    echo
    echo "セットアップ手順:"
    echo "1. Gemini APIキーを設定:"
    echo "   export GEMINI_API_KEY=\"your-api-key\""
    echo
    echo "2. Lazygitでファイルをステージ後、Ctrl+Gを押してAIコミットメッセージを生成"
    echo
    echo "3. 設定をカスタマイズ:"
    echo "   $CONFIG_DIR/config/default.yml を編集"
    echo "   または ai-commit-generator --generate-sample-config でサンプル設定を生成"
    echo
    echo "4. システム診断:"
    echo "   ai-commit-generator --diagnose"
    echo
    echo "トラブルシューティング:"
    echo "- ドキュメント: https://github.com/your-repo/ai-commit-generator"
    echo "- Issue報告: https://github.com/your-repo/ai-commit-generator/issues"
}

# アンインストール
uninstall() {
    log_info "アンインストールを開始..."

    # インストールしたファイルを削除
    if [[ -f "$INSTALL_DIR/ai-commit-generator" ]]; then
        rm -f "$INSTALL_DIR/ai-commit-generator"
        log_success "メインスクリプトを削除しました"
    fi

    if [[ -d "$INSTALL_DIR/src" ]]; then
        rm -rf "$INSTALL_DIR/src"
        log_success "ソースファイルを削除しました"
    fi

    if [[ -d "$INSTALL_DIR/scripts" ]]; then
        rm -rf "$INSTALL_DIR/scripts"
        log_success "スクリプトファイルを削除しました"
    fi

    # 設定ディレクトリ（ユーザーに確認）
    if [[ -d "$CONFIG_DIR" ]]; then
        if [[ -t 0 ]]; then
            if read -p "設定ディレクトリも削除しますか？ [y/N]: " -r; then
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf "$CONFIG_DIR"
                    log_success "設定ディレクトリを削除しました"
                else
                    log_info "設定ディレクトリは保持されました: $CONFIG_DIR"
                fi
            else
                log_info "設定ディレクトリは保持されました: $CONFIG_DIR"
            fi
        else
            log_info "非対話モード: 設定ディレクトリは保持されました: $CONFIG_DIR"
        fi
    fi

    # Lazygit設定（ユーザーに確認）
    local lazygit_config="$LAZYGIT_CONFIG_DIR/config.yml"
    if [[ -f "$lazygit_config" ]] && grep -q "ai-commit-generator" "$lazygit_config" 2>/dev/null; then
        if [[ -t 0 ]]; then
            read -p "Lazygit設定からAI Commit Generatorの設定を削除しますか？ [y/N]: " -r || REPLY=""
        else
            REPLY="N"
        fi
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # バックアップを作成
            cp "$lazygit_config" "$lazygit_config.backup.$(date +%Y%m%d_%H%M%S)"

            # AI Commit Generatorの設定を削除（移植性対応）
            if command -v yq >/dev/null 2>&1; then
                # yqで安全に削除
                yq eval 'del(.customCommands[] | select(.key == "ai-commit-generator"))' "$lazygit_config" > "$lazygit_config.tmp" && mv "$lazygit_config.tmp" "$lazygit_config"
            else
                # sedの移植性対応（一時ファイル経由）
                grep -v 'ai-commit-generator' "$lazygit_config" > "$lazygit_config.tmp" && mv "$lazygit_config.tmp" "$lazygit_config"
            fi
            log_success "Lazygit設定からAI Commit Generatorの設定を削除しました"
        else
            log_info "Lazygit設定は保持されました"
        fi
    fi

    log_success "アンインストールが完了しました"
}

# メイン関数
main() {
    local force_install=false
    local uninstall_mode=false

    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -u|--uninstall)
                uninstall_mode=true
                shift
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --skip-lazygit-config)
                SKIP_LAZYGIT_CONFIG=true
                shift
                ;;
            *)
                log_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # アンインストールモード
    if [[ "$uninstall_mode" == "true" ]]; then
        uninstall
        exit 0
    fi

    # インストールモード
    log_info "AI Commit Generator インストールを開始..."

    # 既存インストールチェック
    if [[ -f "$INSTALL_DIR/ai-commit-generator" ]] && [[ "$force_install" != "true" ]]; then
        log_error "AI Commit Generatorは既にインストールされています"
        echo "強制上書きする場合は --force オプションを使用してください"
        exit 1
    fi

    # インストール実行
    check_dependencies
    create_directories
    install_files
    update_lazygit_config
    update_path
    show_install_complete

    log_success "インストールプロセス完了"
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
