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
  --skip-key-tools        キー送信ツールのインストールをスキップ

例:
  ./install.sh                    # 標準インストール
  ./install.sh --force            # 強制上書きインストール
  ./install.sh --uninstall        # アンインストール
EOF
}

# キー送信ツールをインストール
install_key_sending_tools() {
    log_info "キー送信ツールのインストールを確認中..."
    
    local need_install=false
    local tools_to_install=()
    
    # 環境判定とツール選択
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        if ! command -v ydotool >/dev/null 2>&1; then
            tools_to_install+=("ydotool")
            need_install=true
        fi
    else
        # X11環境またはDISPLAY環境
        if ! command -v xdotool >/dev/null 2>&1; then
            tools_to_install+=("xdotool")
            need_install=true
        fi
    fi
    
    # tmuxは手動インストールのみ（自動インストールしない）
    
    if [[ "$need_install" == "true" ]]; then
        log_info "キー送信ツールをインストール中: ${tools_to_install[*]}"
        
        # パッケージ管理システムに応じてインストール
        if command -v apt >/dev/null 2>&1; then
            log_info "APTを使用してパッケージをインストール..."
            for tool in "${tools_to_install[@]}"; do
                if ! dpkg -l | grep -q "^ii.*$tool"; then
                    log_info "インストール中: $tool"
                    
                    # ydotoolの場合は依存関係も含めてインストール
                    if [[ "$tool" == "ydotool" ]]; then
                        log_info "ydotoolと関連パッケージをインストール中..."
                        if sudo apt update 2>&1 && sudo apt install -y ydotool ydotoold 2>&1; then
                            log_success "ydotool のインストール完了"
                            
                            # ydotoolの詳細設定
                            log_info "ydotoolの詳細設定を実行中..."
                            
                            # inputグループにユーザーを追加
                            if sudo usermod -a -G input "$USER" 2>/dev/null; then
                                log_success "ユーザーをinputグループに追加しました"
                            else
                                log_warn "inputグループへの追加に失敗（権限またはグループが存在しない可能性）"
                            fi
                            
                            # ydotoolサービスファイルが存在するかチェック（ydotooldも含む）
                            local ydotool_service=""
                            if systemctl list-unit-files | grep -q "ydotoold"; then
                                ydotool_service="ydotoold"
                            elif systemctl list-unit-files | grep -q "ydotool"; then
                                ydotool_service="ydotool"
                            fi
                            
                            if [[ -n "$ydotool_service" ]]; then
                                log_info "${ydotool_service}サービスを有効化中..."
                                if sudo systemctl enable --now "$ydotool_service" 2>/dev/null; then
                                    log_success "${ydotool_service}サービス有効化完了"
                                else
                                    log_warn "${ydotool_service}サービスの有効化に失敗"
                                fi
                            else
                                log_info "ydotoolサービスファイルが見つかりません - 手動設定を実行"
                                
                                # 手動でydotooldを設定
                                log_info "ydotool手動設定スクリプトを作成中..."
                                
                                # ydotool起動スクリプトを作成
                                cat > /tmp/setup_ydotool.sh << 'EOF'
#!/bin/bash

# ydotool手動設定スクリプト
echo "ydotoolの手動設定を開始..."

# 既存のydotooldプロセスを停止
sudo pkill ydotoold 2>/dev/null || true

# 既存のソケットを削除
sudo rm -f /tmp/.ydotool_socket

# ydotooldをバックグラウンドで起動
echo "ydotooldをバックグラウンドで起動中..."
sudo ydotoold &

# 少し待機してソケットが作成されるのを待つ
sleep 2

# ソケットの権限を設定（セキュアな権限）
if [ -e /tmp/.ydotool_socket ]; then
    if getent group input >/dev/null 2>&1; then
        sudo chgrp input /tmp/.ydotool_socket || true
        sudo chmod 660 /tmp/.ydotool_socket
        echo "✅ ydotoolソケットの権限を660 (group: input) に設定しました"
    else
        echo "⚠️ 'input' グループが見つかりません。最小権限運用のため 'input' グループの作成/付与を検討してください" >&2
        sudo chmod 660 /tmp/.ydotool_socket
        echo "✅ 暫定で 660 を適用しました"
    fi
    echo "ydotool設定完了！"
else
    echo "❌ ydotoolソケットの作成に失敗しました"
    exit 1
fi

echo "ydotoolのテスト実行..."
if ydotool key --help >/dev/null 2>&1; then
    echo "✅ ydotoolが正常に動作しています"
else
    echo "❌ ydotoolの動作に問題があります"
fi
EOF
                                
                                chmod +x /tmp/setup_ydotool.sh
                                log_info "ydotool設定スクリプトを実行中..."
                                
                                if bash /tmp/setup_ydotool.sh; then
                                    log_success "ydotool手動設定が完了しました"
                                else
                                    log_warn "ydotool手動設定に一部問題がありました"
                                fi
                                
                                # クリーンアップ
                                rm -f /tmp/setup_ydotool.sh
                            fi
                        else
                            log_error "ydotool のインストールに失敗"
                            log_info "詳細: sudo apt install -y ydotool ydotoold を手動で実行してください"
                            # ydotoolのインストールに失敗しても継続（tmuxがあれば動作するため）
                        fi
                    else
                        # 通常のパッケージインストール
                        if sudo apt update >/dev/null 2>&1 && sudo apt install -y "$tool" 2>&1; then
                            log_success "$tool のインストール完了"
                        else
                            log_error "$tool のインストールに失敗"
                        fi
                    fi
                else
                    log_info "$tool は既にインストール済み"
                fi
            done
        elif command -v yum >/dev/null 2>&1; then
            log_info "YUMを使用してパッケージをインストール..."
            for tool in "${tools_to_install[@]}"; do
                if sudo yum install -y "$tool"; then
                    log_success "$tool のインストール完了"
                else
                    log_error "$tool のインストールに失敗"
                fi
            done
        elif command -v pacman >/dev/null 2>&1; then
            log_info "Pacmanを使用してパッケージをインストール..."
            for tool in "${tools_to_install[@]}"; do
                if sudo pacman -S --noconfirm "$tool"; then
                    log_success "$tool のインストール完了"
                else
                    log_error "$tool のインストールに失敗"
                fi
            done
        elif command -v brew >/dev/null 2>&1; then
            log_info "Homebrewを使用してパッケージをインストール..."
            for tool in "${tools_to_install[@]}"; do
                # Homebrewでの名前変換
                local brew_name="$tool"
                if [[ "$tool" == "ydotool" ]]; then
                    log_warn "Homebrewではydotoolは利用できません。Waylandユーザーは手動インストールしてください"
                    continue
                fi
                
                brew install "$brew_name" || { log_error "$tool のインストールに失敗"; continue; }
                log_success "$tool のインストール完了"
            done
        else
            log_warn "未知のパッケージ管理システムです。以下を手動でインストールしてください:"
            for tool in "${tools_to_install[@]}"; do
                echo "  - $tool"
            done
            echo ""
            echo "インストール例:"
            echo "  Ubuntu/Debian: sudo apt install ${tools_to_install[*]}"
            echo "  CentOS/RHEL: sudo yum install ${tools_to_install[*]}"
            echo "  Arch Linux: sudo pacman -S ${tools_to_install[*]}"
            return 0
        fi
    else
        log_success "必要なキー送信ツールは既にインストール済みです"
    fi
    
    # インストール後の確認
    log_info "キー送信ツールの動作確認中..."
    local available_tools=()
    
    if command -v tmux >/dev/null 2>&1; then
        available_tools+=("tmux")
    fi
    
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v ydotool >/dev/null 2>&1; then
        available_tools+=("ydotool")
        
        # ydotoolサービス状態確認（ydotoolまydotooldの両方をチェック）
        if systemctl is-active --quiet ydotool 2>/dev/null || systemctl is-active --quiet ydotoold 2>/dev/null; then
            if systemctl is-active --quiet ydotool 2>/dev/null; then
                log_success "ydotoolサービスが実行中です"
            else
                log_success "ydotooldサービスが実行中です"
            fi
        elif [[ -e /tmp/.ydotool_socket ]]; then
            log_info "ydotoolソケットが存在します"
            
            # ソケットの権限確認
            if ydotool key --help >/dev/null 2>&1; then
                log_success "ydotoolが正常に動作しています"
            else
                log_warn "ydotoolソケットにアクセスできません - 権限問題の可能性"
                log_info "解決方法: sudo usermod -aG input $USER && sudo chgrp input /tmp/.ydotool_socket && sudo chmod 660 /tmp/.ydotool_socket"
            fi
        else
            log_warn "ydotoolサービスが停止、かつソケットも存在しません"
            log_info "手動起動方法:"
            log_info "  1. sudo ydotoold &"
            log_info "  2. sudo usermod -aG input $USER && sudo chgrp input /tmp/.ydotool_socket && sudo chmod 660 /tmp/.ydotool_socket"
        fi
    elif command -v xdotool >/dev/null 2>&1; then
        available_tools+=("xdotool")
    fi
    
    if [[ ${#available_tools[@]} -gt 0 ]]; then
        log_success "利用可能なキー送信ツール: ${available_tools[*]}"
        log_info "自動コミットウィンドウ機能が利用可能です"
    else
        log_warn "キー送信ツールが利用できません"
        log_warn "自動コミットウィンドウ機能は動作しませんが、AI生成機能は利用可能です"
        log_info "手動でキー送信ツールをインストールしてください:"
        echo "  - tmux: sudo apt install tmux"
        if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
            echo "  - ydotool: sudo apt install ydotool ydotoold"
            echo "  - サービス有効化: sudo systemctl enable --now ydotool || sudo systemctl enable --now ydotoold"
        else
            echo "  - xdotool: sudo apt install xdotool"
        fi
        # エラーで終了せず、警告として継続
    fi
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
    echo "   ※ 自動コミットウィンドウ機能が有効になります"
    echo
    echo "3. 設定をカスタマイズ:"
    echo "   $CONFIG_DIR/config/default.yml を編集"
    echo "   または ai-commit-generator --generate-sample-config でサンプル設定を生成"
    echo
    echo "4. システム診断:"
    echo "   ai-commit-generator --diagnose"
    echo
    echo "5. キー送信ツール確認:"
    echo "   - tmux環境: 推奨（最も安定）"
    echo "   - X11環境: xdotool を使用"
    echo "   - Wayland環境: ydotool を使用"
    echo "   ※ 自動コミットウィンドウが動作しない場合:"
    echo "     - ログ確認: /tmp/lazygit_auto_commit.log"
    echo "     - ydotool手動起動: sudo ydotoold & && sudo usermod -aG input $USER && sudo chgrp input /tmp/.ydotool_socket && sudo chmod 660 /tmp/.ydotool_socket"
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
            --skip-key-tools)
                SKIP_KEY_TOOLS=true
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
    
    # キー送信ツールのインストール（オプション）
    if [[ "${SKIP_KEY_TOOLS:-false}" != "true" ]]; then
        install_key_sending_tools
    else
        log_info "キー送信ツールのインストールをスキップしました"
        log_warn "自動コミットウィンドウ機能は利用できません"
    fi
    
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