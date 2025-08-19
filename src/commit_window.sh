#!/bin/bash
# AI Commit Generator - 専用コミットメッセージ入力ウィンドウ
# 独自TUIベースのコミットメッセージ編集ウィンドウ

set -euo pipefail

# 必要なモジュールを読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/ui_helper.sh"

# コミットウィンドウの設定
COMMIT_WINDOW_WIDTH=80
COMMIT_WINDOW_HEIGHT=20
TEMP_MESSAGE_FILE="/tmp/ai-commit-message-edit.txt"
TEMP_INPUT_FILE="/tmp/ai-commit-input.tmp"

# ターミナルサイズを取得
get_terminal_size() {
    local width height
    if command -v tput >/dev/null 2>&1; then
        width=$(tput cols 2>/dev/null || echo 80)
        height=$(tput lines 2>/dev/null || echo 24)
    else
        width=80
        height=24
    fi
    echo "$width $height"
}

# ターミナルの状態を保存
save_terminal_state() {
    tput smcup 2>/dev/null || true  # 代替画面バッファに切り替え
    stty -echo 2>/dev/null || true  # エコーを無効化
}

# ターミナルの状態を復元
restore_terminal_state() {
    tput rmcup 2>/dev/null || true  # 通常画面バッファに戻す
    stty echo 2>/dev/null || true   # エコーを有効化
    clear
}

# ボックスを描画
draw_box() {
    local x=$1 y=$2 width=$3 height=$4 title="$5"
    local i
    
    # 上端
    tput cup $y $x
    echo -n "┌"
    for ((i=1; i<width-1; i++)); do echo -n "─"; done
    echo -n "┐"
    
    # タイトル
    if [[ -n "$title" ]]; then
        local title_x=$((x + (width - ${#title}) / 2))
        tput cup $y $title_x
        echo -n "[ $title ]"
    fi
    
    # 側面
    for ((i=1; i<height-1; i++)); do
        tput cup $((y + i)) $x
        echo -n "│"
        tput cup $((y + i)) $((x + width - 1))
        echo -n "│"
    done
    
    # 下端
    tput cup $((y + height - 1)) $x
    echo -n "└"
    for ((i=1; i<width-1; i++)); do echo -n "─"; done
    echo -n "┘"
}

# テキストを中央に表示
draw_centered_text() {
    local y=$1 text="$2" width=${3:-$COMMIT_WINDOW_WIDTH}
    local x=$(( ($(tput cols) - width) / 2 ))
    local text_x=$(( x + (width - ${#text}) / 2 ))
    
    tput cup $y $text_x
    echo -n "$text"
}

# ヘルプテキストを表示
draw_help() {
    local start_y=$1
    local help_texts=(
        "Ctrl+Enter: コミット実行"
        "Ctrl+C: キャンセル"
        "↑/↓: カーソル移動"
        "Enter: 改行"
    )
    
    local y=$start_y
    for help_text in "${help_texts[@]}"; do
        draw_centered_text $y "$help_text"
        ((y++))
    done
}

# メッセージテキストエリアを描画
draw_message_area() {
    local start_x=$1 start_y=$2 width=$3 height=$4
    local message="$5"
    
    # メッセージを行ごとに分割
    local lines=()
    local current_line=""
    local max_line_width=$((width - 4))  # 左右のパディング分を除く
    
    # メッセージを単語ごとに分割して行に配置
    while IFS= read -r line; do
        if [[ ${#line} -le $max_line_width ]]; then
            lines+=("$line")
        else
            # 長い行を分割
            local remaining="$line"
            while [[ ${#remaining} -gt $max_line_width ]]; do
                lines+=("${remaining:0:$max_line_width}")
                remaining="${remaining:$max_line_width}"
            done
            if [[ -n "$remaining" ]]; then
                lines+=("$remaining")
            fi
        fi
    done <<< "$message"
    
    # 最大表示行数に調整
    local max_lines=$((height - 2))
    if [[ ${#lines[@]} -gt $max_lines ]]; then
        lines=("${lines[@]:0:$max_lines}")
    fi
    
    # テキストエリアを描画
    local y=$((start_y + 1))
    for line in "${lines[@]}"; do
        tput cup $y $((start_x + 2))
        printf "%-${max_line_width}s" "$line"
        ((y++))
    done
    
    # 残りの行をクリア
    while [[ $y -lt $((start_y + height - 1)) ]]; do
        tput cup $y $((start_x + 2))
        printf "%-${max_line_width}s" ""
        ((y++))
    done
}

# カーソル位置を管理
CURSOR_Y=0
MAX_CURSOR_Y=0

update_cursor_position() {
    local message="$1"
    local lines_count
    lines_count=$(echo "$message" | wc -l)
    MAX_CURSOR_Y=$((lines_count - 1))
    
    if [[ $CURSOR_Y -gt $MAX_CURSOR_Y ]]; then
        CURSOR_Y=$MAX_CURSOR_Y
    fi
    if [[ $CURSOR_Y -lt 0 ]]; then
        CURSOR_Y=0
    fi
}

# メイン画面を描画
draw_commit_window() {
    local message="$1"
    
    clear
    
    # ターミナルサイズを取得
    local term_size
    term_size=$(get_terminal_size)
    local term_width=${term_size% *}
    local term_height=${term_size#* }
    
    # ウィンドウサイズを調整
    local window_width=$COMMIT_WINDOW_WIDTH
    local window_height=$COMMIT_WINDOW_HEIGHT
    
    if [[ $window_width -gt $term_width ]]; then
        window_width=$((term_width - 4))
    fi
    if [[ $window_height -gt $term_height ]]; then
        window_height=$((term_height - 4))
    fi
    
    # ウィンドウの位置を計算
    local start_x=$(( (term_width - window_width) / 2 ))
    local start_y=$(( (term_height - window_height) / 2 ))
    
    # メインボックスを描画
    draw_box $start_x $start_y $window_width $window_height "AI Generated Commit Message"
    
    # メッセージエリアの位置とサイズ
    local msg_area_height=$((window_height - 8))
    local msg_area_y=$((start_y + 2))
    
    # メッセージエリアを描画
    draw_message_area $start_x $msg_area_y $window_width $msg_area_height "$message"
    
    # ヘルプエリアを描画
    local help_y=$((start_y + window_height - 5))
    draw_help $help_y
    
    # ステータス行
    local status_y=$((start_y + window_height - 2))
    draw_centered_text $status_y "Ready to commit" $window_width
}

# シンプルなテキストエディター機能（dialog使用）
edit_message_with_dialog() {
    local initial_message="$1"
    local temp_file="$TEMP_MESSAGE_FILE"
    
    # 初期メッセージをファイルに保存
    echo "$initial_message" > "$temp_file"
    
    # dialogでテキストエディターを起動
    if command -v dialog >/dev/null 2>&1; then
        if dialog --title "AI Generated Commit Message" \
                  --editbox "$temp_file" 20 80 2>"$TEMP_INPUT_FILE"; then
            # OKが押された場合、編集されたメッセージを返す
            if [[ -f "$TEMP_INPUT_FILE" ]]; then
                cat "$TEMP_INPUT_FILE"
                rm -f "$TEMP_INPUT_FILE"
                return 0
            fi
        fi
    else
        log_warn "dialog コマンドが見つかりません。代替エディターを使用します"
        edit_message_with_nano "$initial_message"
        return $?
    fi
    
    # キャンセルまたはエラー
    rm -f "$TEMP_INPUT_FILE" 2>/dev/null || true
    return 1
}

# nano/viエディターを使用
edit_message_with_nano() {
    local initial_message="$1"
    local temp_file="$TEMP_MESSAGE_FILE"
    
    # 初期メッセージをファイルに保存
    echo "$initial_message" > "$temp_file"
    
    # エディターを選択
    local editor
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        log_error "利用可能なエディターが見つかりません"
        return 1
    fi
    
    echo "プレスEnterでエディターを開きます（$editor）..."
    read -r
    
    # エディターを起動
    if "$editor" "$temp_file"; then
        cat "$temp_file"
        return 0
    else
        return 1
    fi
}

# whiptailを使用したシンプルな入力
edit_message_with_whiptail() {
    local initial_message="$1"
    
    if command -v whiptail >/dev/null 2>&1; then
        # whiptailのテキストボックスを使用
        if whiptail --title "AI Generated Commit Message" \
                   --inputbox "編集してください:" 10 80 "$initial_message" \
                   3>&1 1>&2 2>&3; then
            return 0
        fi
    else
        log_warn "whiptail コマンドが見つかりません"
        return 1
    fi
    
    return 1
}

# Lazygitモード専用の対話エディター
edit_message_lazygit_interactive() {
    local initial_message="$1"
    
    # プロンプト表示（標準エラーに出力してログと分離）
    echo >&2
    echo "🤖 AI生成コミットメッセージ:" >&2
    echo "==================================" >&2
    echo "$initial_message" >&2
    echo "==================================" >&2
    echo >&2
    echo "📝 選択してください:" >&2
    echo "1) このメッセージをそのまま使用" >&2
    echo "2) メッセージを編集" >&2
    echo "3) キャンセル" >&2
    echo >&2
    
    local choice
    echo -n "選択 (1-3): " >&2
    read choice
    
    case "$choice" in
        1)
            echo "$initial_message"
            return 0
            ;;
        2)
            echo "新しいコミットメッセージを入力してください:" >&2
            local new_message
            echo -n "> " >&2
            read new_message
            
            if [[ -n "$new_message" ]]; then
                echo "$new_message"
                return 0
            else
                echo "❌ 空のメッセージは無効です" >&2
                return 1
            fi
            ;;
        3|*)
            echo "キャンセルされました" >&2
            return 1
            ;;
    esac
}

# 直接テスト用の関数
test_window_direct() {
    local test_message="${1:-feat: テスト用メッセージ}"
    echo "🧪 ウィンドウ関数の直接テスト"
    echo "メッセージ: $test_message"
    echo
    
    local result
    result=$(edit_message_lazygit_interactive "$test_message")
    echo "結果: $result"
}

# フォールバック用のシンプルな入力方法
edit_message_fallback() {
    local initial_message="$1"
    
    # Lazygitモードでは自動的に元のメッセージを使用
    if [[ "${LAZYGIT_MODE:-false}" == "true" ]]; then
        log_info "Lazygitモード: AI生成メッセージをそのまま使用"
        echo "$initial_message"
        return 0
    fi
    
    echo "📝 カスタムエディターが利用できません。シンプル編集モードを使用します。"
    echo
    echo "現在のAI生成メッセージ:"
    echo "------------------------"
    echo "$initial_message"
    echo "------------------------"
    echo
    
    local choice
    echo "選択してください:"
    echo "1) このメッセージをそのまま使用"
    echo "2) 新しいメッセージを入力"
    echo "3) キャンセル"
    
    # 非対話環境では自動的に元のメッセージを使用
    if [[ ! -t 0 ]] || [[ "${CI:-false}" == "true" ]]; then
        echo "非対話環境のため、AI生成メッセージをそのまま使用します"
        echo "$initial_message"
        return 0
    fi
    
    read -p "選択 (1-3): " choice
    
    case "$choice" in
        1)
            echo "$initial_message"
            return 0
            ;;
        2)
            echo "新しいコミットメッセージを入力してください:"
            local new_message
            read -p "> " new_message
            if [[ -n "$new_message" ]]; then
                echo "$new_message"
                return 0
            else
                echo "❌ 空のメッセージは無効です"
                return 1
            fi
            ;;
        3|*)
            echo "キャンセルされました"
            return 1
            ;;
    esac
}

# メイン関数：AIコミットメッセージウィンドウを表示
show_ai_commit_window() {
    local ai_message="$1"
    local edited_message=""
    
    log_info "🖥️  AI Generated Commit Message Window を起動中..."
    
    # メッセージが空でないかチェック
    if [[ -z "$ai_message" ]]; then
        log_error "❌ AI生成メッセージが空です"
        return 1
    fi
    
    # ターミナルの互換性をチェック
    if ! command -v tput >/dev/null 2>&1; then
        log_warn "tput コマンドが見つかりません。代替エディターを使用します"
        edit_message_with_nano "$ai_message"
        return $?
    fi
    
    # Lazygitモードでは専用の対話エディターを使用
    local editors=()
    if [[ "${LAZYGIT_MODE:-false}" == "true" ]]; then
        # Lazygitモードでは、TERM変数があれば対話可能とみなす
        if [[ -n "${TERM:-}" && "$TERM" != "dumb" ]]; then
            # ターミナル環境が利用可能
            editors=(
                "edit_message_lazygit_interactive"
                "edit_message_fallback"
            )
            log_info "Lazygitモード: 専用対話エディターを使用 (TERM=$TERM)"
        else
            # 非対話環境の場合
            editors=(
                "edit_message_fallback"
            )
            log_info "Lazygitモード: 非対話環境、フォールバックを使用"
        fi
    else
        editors=(
            "edit_message_with_dialog"
            "edit_message_with_whiptail" 
            "edit_message_with_nano"
            "edit_message_fallback"
        )
    fi
    
    for editor_func in "${editors[@]}"; do
        log_info "エディター試行中: $editor_func"
        
        # 関数が存在するかチェック
        if ! declare -f "$editor_func" >/dev/null 2>&1; then
            log_error "関数 $editor_func が定義されていません"
            continue
        fi
        
        log_info "$editor_func を実行します..."
        
        # 直接関数を呼び出し（標準エラーと標準出力を分離）
        local temp_stderr temp_stdout
        temp_stderr=$(mktemp)
        temp_stdout=$(mktemp)
        
        if $editor_func "$ai_message" >"$temp_stdout" 2>"$temp_stderr"; then
            local exit_code=$?
            edited_message=$(cat "$temp_stdout")
            local stderr_content=$(cat "$temp_stderr")
            
            log_info "$editor_func の終了コード: $exit_code"
            if [[ -n "$stderr_content" ]]; then
                log_debug "$editor_func のstderr: $stderr_content"
            fi
            
            if [[ $exit_code -eq 0 && -n "$edited_message" ]]; then
                log_info "✅ コミットメッセージが編集されました ($editor_func)"
                log_debug "編集後メッセージ: $edited_message"
                rm -f "$temp_stderr" "$temp_stdout"
                echo "$edited_message"
                return 0
            else
                log_warn "$editor_func は空の結果または失敗を返しました (exit_code: $exit_code)"
            fi
        else
            local exit_code=$?
            log_error "$editor_func の実行に失敗しました (exit_code: $exit_code)"
        fi
        
        rm -f "$temp_stderr" "$temp_stdout"
        
        log_warn "$editor_func は使用できませんでした - 次のエディターを試行"
    done
    
    # すべて失敗した場合（これは通常発生しない）
    log_error "❌ すべてのエディターオプションが失敗しました"
    echo "❌ エラー: エディターの起動に失敗しました"
    echo "💡 フォールバック: 元のAI生成メッセージを使用してください"
    echo "$ai_message"
    return 0  # フォールバックとして元のメッセージを返す
}

# 確認ダイアログを表示してコミット実行
confirm_and_commit() {
    local message="$1"
    local skip_confirmation="${2:-false}"  # Lazygitモードでは確認をスキップ可能
    
    # メッセージが空でないかチェック
    if [[ -z "$message" || "$message" =~ ^[[:space:]]*$ ]]; then
        log_error "❌ コミットメッセージが空です"
        echo "❌ エラー: コミットメッセージが空です"
        return 1
    fi
    
    # ステージされたファイルがあるかチェック
    if ! git diff --cached --quiet; then
        # Lazygitモード用：確認を簡略化
        if [[ "$skip_confirmation" == "true" ]] || [[ "${LAZYGIT_MODE:-false}" == "true" ]]; then
            echo
            echo "📝 最終コミットメッセージ:"
            echo "=================================="
            echo "$message"
            echo "=================================="
            echo
            
            log_info "🚀 コミットを実行中..."
            if git commit -m "$message"; then
                echo "✅ コミット完了！"
                log_info "✅ コミット完了！"
                return 0
            else
                echo "❌ コミットに失敗しました"
                log_error "Git commit failed with message: $message"
                return 1
            fi
        else
            # 通常モード：確認ダイアログ表示
            echo
            echo "=== Generated Commit Message ==="
            echo "$message"
            echo "=============================="
            echo
            
            if show_confirmation "コミット確認" "このメッセージでコミットを実行しますか？"; then
                log_info "🚀 コミットを実行中..."
                
                if git commit -m "$message"; then
                    show_success "✅ コミット完了！"
                    return 0
                else
                    show_error "❌ コミットに失敗しました"
                    log_error "Git commit failed with message: $message"
                    return 1
                fi
            else
                log_info "ユーザーによってコミットがキャンセルされました"
                return 1
            fi
        fi
    else
        log_error "❌ ステージされたファイルがありません"
        echo "❌ エラー: ステージされたファイルがありません"
        echo "💡 ヒント: ファイルをステージしてからコミットしてください"
        return 1
    fi
}

# クリーンアップ
cleanup_commit_window() {
    rm -f "$TEMP_MESSAGE_FILE" "$TEMP_INPUT_FILE" 2>/dev/null || true
    restore_terminal_state
}

# シグナルハンドラー設定
setup_commit_window_signals() {
    trap cleanup_commit_window EXIT
    trap cleanup_commit_window SIGINT
    trap cleanup_commit_window SIGTERM
}

# 使用方法表示
show_commit_window_usage() {
    cat <<EOF
AI Commit Window Usage:

show_ai_commit_window <ai_generated_message>
    AIが生成したコミットメッセージを表示・編集するウィンドウを開きます

confirm_and_commit <message>
    コミットメッセージを確認してコミットを実行します

例:
    message="\$(ai-commit-generator --generate-only)"
    edited_message="\$(show_ai_commit_window "\$message")"
    confirm_and_commit "\$edited_message"
EOF
}

# このスクリプトが直接実行された場合の処理
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # デモ実行
    if [[ $# -eq 0 ]]; then
        show_commit_window_usage
        exit 0
    fi
    
    setup_commit_window_signals
    
    case "${1:-}" in
        --demo)
            demo_message="feat: Add new AI commit window functionality

- Implement custom TUI-based commit message editor
- Support for dialog, whiptail, and nano editors
- Add confirmation dialog before commit
- Include proper cleanup and signal handling"
            
            if edited_message=$(show_ai_commit_window "$demo_message"); then
                echo "編集されたメッセージ:"
                echo "$edited_message"
            else
                echo "編集がキャンセルされました"
                exit 1
            fi
            ;;
        --help)
            show_commit_window_usage
            ;;
        *)
            # 引数をメッセージとして処理
            if edited_message=$(show_ai_commit_window "$*"); then
                echo "$edited_message"
            else
                exit 1
            fi
            ;;
    esac
fi