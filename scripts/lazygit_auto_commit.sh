#!/bin/bash
# Lazygit自動コミットウィンドウ表示スクリプト
# AI生成完了後にコミット概要編集ウィンドウ（'c'キー）を自動実行

set -uo pipefail

# ログファイル
LOG_FILE="/tmp/lazygit_auto_commit.log"

# ログ関数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

log_message "=== Lazygit自動コミット開始 ==="

# 詳細な環境情報をログに記録
log_message "環境情報収集開始"
log_message "USER: ${USER:-unknown}"
log_message "HOME: ${HOME:-unknown}"
log_message "PWD: $(pwd)"
log_message "SHELL: ${SHELL:-unknown}"
log_message "TERM: ${TERM:-unknown}"
log_message "DISPLAY: ${DISPLAY:-unset}"
log_message "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-unset}"
log_message "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-unset}"
log_message "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-unset}"
log_message "TMUX: ${TMUX:-unset}"
log_message "TMUX_PANE: ${TMUX_PANE:-unset}"

# 利用可能なツールをチェック
log_message "利用可能ツールチェック:"
log_message "  tmux: $(command -v tmux >/dev/null 2>&1 && echo "利用可能" || echo "なし")"
log_message "  xdotool: $(command -v xdotool >/dev/null 2>&1 && echo "利用可能" || echo "なし")"
log_message "  ydotool: $(command -v ydotool >/dev/null 2>&1 && echo "利用可能" || echo "なし")"

# プロセス情報
log_message "関連プロセス情報:"
log_message "  lazygit: $(pgrep -f lazygit >/dev/null 2>&1 && echo "実行中" || echo "なし")"
log_message "  Xorg: $(pgrep -f Xorg >/dev/null 2>&1 && echo "実行中" || echo "なし")"
log_message "  gnome-shell: $(pgrep -f gnome-shell >/dev/null 2>&1 && echo "実行中" || echo "なし")"

# AI生成完了を待機
sleep 2
log_message "AI生成完了待機終了、コミットウィンドウ表示を開始"

# 成功フラグ
success=false

# 環境検出とキー送信
if [[ -n "${TMUX:-}" ]]; then
    log_message "tmux環境を検出"
    log_message "TMUX変数: ${TMUX}"
    log_message "TMUX_PANE: ${TMUX_PANE:-unset}"
    
    # tmuxセッション情報を取得
    if command -v tmux >/dev/null 2>&1; then
        log_message "tmuxセッション一覧:"
        tmux list-sessions 2>/dev/null | while read session; do
            log_message "  $session"
        done
        
        log_message "現在のペイン情報:"
        tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}" 2>/dev/null | while read pane; do
            log_message "  現在のペイン: $pane"
        done
    fi
    
    log_message "tmux環境でコミットキー送信を実行"
    if tmux send-keys c 2>/dev/null; then
        success=true
        log_message "tmux環境でコミットキー送信成功"
    else
        tmux_error=$?
        log_message "tmux環境でコミットキー送信失敗 (終了コード: $tmux_error)"
        
        # 詳細なエラー診断
        log_message "tmuxエラー診断:"
        log_message "  tmuxバージョン: $(tmux -V 2>/dev/null || echo "取得失敗")"
        log_message "  tmux server情報: $(tmux info 2>/dev/null | head -3 || echo "取得失敗")"
    fi
elif [[ "$XDG_SESSION_TYPE" == "wayland" ]] && command -v ydotool >/dev/null 2>&1; then
    log_message "Wayland環境でydotoolを使用"
    
    # ydotoolでキー送信
    if ydotool key 46:1 46:0 2>/dev/null; then  # 46 = 'c'キー
        success=true
        log_message "ydotoolでコミットキー送信成功"
    else
        log_message "ydotoolでコミットキー送信失敗"
    fi
elif command -v xdotool >/dev/null 2>&1; then
    log_message "X11環境でxdotoolを使用"
    log_message "xdotoolバージョン: $(xdotool --version 2>/dev/null || echo "取得失敗")"
    
    # X11ディスプレイ情報
    log_message "X11ディスプレイ情報:"
    log_message "  DISPLAY: ${DISPLAY:-unset}"
    log_message "  Xサーバー確認: $(xdpyinfo >/dev/null 2>&1 && echo "接続可能" || echo "接続不可")"
    
    # ウィンドウ一覧を取得
    log_message "利用可能ウィンドウ:"
    if windows=$(xdotool search --name ".*" 2>/dev/null | head -5); then
        echo "$windows" | while read window_id; do
            if [[ -n "$window_id" ]]; then
                window_name=$(xdotool getwindowname "$window_id" 2>/dev/null || echo "unknown")
                log_message "  ウィンドウID: $window_id, 名前: $window_name"
            fi
        done
    else
        log_message "  ウィンドウ検索に失敗"
    fi
    
    # 現在のアクティブウィンドウを対象にする
    active_window=$(xdotool getactivewindow 2>/dev/null)
    if [[ -n "$active_window" ]]; then
        window_name=$(xdotool getwindowname "$active_window" 2>/dev/null || echo "unknown")
        window_class=$(xdotool getwindowclassname "$active_window" 2>/dev/null || echo "unknown")
        log_message "アクティブウィンドウ: $active_window"
        log_message "  名前: $window_name"
        log_message "  クラス: $window_class"
        
        # 特定のlazygitウィンドウを検索
        log_message "lazygit関連ウィンドウ検索:"
        if lazygit_windows=$(xdotool search --name "lazygit" 2>/dev/null); then
            log_message "  lazygit名前検索: 見つかった"
            echo "$lazygit_windows" | while read lw; do
                log_message "    ウィンドウID: $lw"
            done
        else
            log_message "  lazygit名前検索: 見つからない"
        fi
        
        # 直接'c'キーを送信
        log_message "キー送信を実行 (対象ウィンドウ: $active_window)"
        if xdotool key --clearmodifiers c 2>/dev/null; then
            success=true
            log_message "xdotoolでコミットキー送信成功"
        else
            xdotool_error=$?
            log_message "xdotoolでコミットキー送信失敗 (終了コード: $xdotool_error)"
            
            # 別の方法でキー送信を試行
            log_message "ウィンドウ指定でキー送信を再試行"
            if xdotool key --window "$active_window" c 2>/dev/null; then
                success=true
                log_message "ウィンドウ指定キー送信成功"
            else
                log_message "ウィンドウ指定キー送信も失敗"
            fi
        fi
    else
        log_message "アクティブウィンドウの取得に失敗"
        log_message "X11接続状態: $(echo $DISPLAY | grep -q ":" && echo "正常" || echo "異常")"
    fi
elif command -v ydotool >/dev/null 2>&1; then
    log_message "Wayland環境でydotoolを使用"
    log_message "ydotoolソケット確認: $(ls -la /tmp/.ydotool_socket 2>/dev/null || echo "ソケットなし")"
    
    # ydotoolでキー送信
    log_message "ydotoolでキー送信を実行中..."
    log_message "対象アプリケーション: lazygit (PID: $(pgrep lazygit 2>/dev/null || echo "見つからない"))"
    
    # 少し待機してからキー送信（アプリケーションが準備できるまで）
    log_message "1秒待機後にキー送信実行..."
    sleep 1
    
    ydotool_output=$(ydotool key 46:1 46:0 2>&1)  # cキーのキーコード(46)でpress:release
    ydotool_exit_code=$?
    
    log_message "ydotool実行結果: 終了コード=$ydotool_exit_code"
    log_message "ydotool出力: $ydotool_output"
    
    # 追加の診断情報
    log_message "キー送信後の状況確認:"
    log_message "  現在時刻: $(date '+%H:%M:%S')"
    log_message "  lazygitプロセス: $(pgrep lazygit >/dev/null && echo "実行中" || echo "停止")"
    
    if [[ $ydotool_exit_code -eq 0 ]]; then
        success=true
        log_message "ydotoolでコミットキー送信成功"
    else
        log_message "ydotoolでコミットキー送信失敗"
        log_message "エラー詳細: $ydotool_output"
        
        # 代替方法として少し待機してから再試行
        log_message "0.5秒待機後に再試行..."
        sleep 0.5
        
        ydotool_output=$(ydotool key 46:1 46:0 2>&1)  # 修正されたcキーコード
        ydotool_exit_code=$?
        
        if [[ $ydotool_exit_code -eq 0 ]]; then
            success=true
            log_message "ydotool再試行で成功"
        else
            log_message "ydotool再試行も失敗: $ydotool_output"
        fi
    fi
else
    log_message "利用可能なキー送信ツールが見つかりません"
    log_message "環境: XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-未設定}"
    
    # 詳細な診断情報
    log_message "詳細診断:"
    log_message "  OS: $(uname -a)"
    log_message "  X11 SESSION: ${XDG_SESSION_TYPE:-unknown}"
    log_message "  DESKTOP ENV: ${XDG_CURRENT_DESKTOP:-unknown}"
    
    # パッケージ管理システムの確認
    log_message "パッケージ管理システム:"
    if command -v apt >/dev/null 2>&1; then
        log_message "  apt: 利用可能"
        log_message "  xdotool package: $(dpkg -l | grep xdotool || echo "未インストール")"
        log_message "  ydotool package: $(dpkg -l | grep ydotool || echo "未インストール")"
    elif command -v yum >/dev/null 2>&1; then
        log_message "  yum: 利用可能"
    elif command -v pacman >/dev/null 2>&1; then
        log_message "  pacman: 利用可能"
    else
        log_message "  不明なパッケージ管理システム"
    fi
    
    log_message "推奨インストール:"
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        log_message "  Wayland環境: sudo apt install ydotool"
        log_message "  インストール後: sudo systemctl enable --now ydotool"
    else
        log_message "  X11環境: sudo apt install xdotool"
    fi
    
    log_message "または tmux環境での使用を推奨"
    log_message "tmux起動: tmux new-session -d -s lazygit"
fi

# 結果ログとユーザー指示
if [[ "$success" == "true" ]]; then
    log_message "=== コミットウィンドウ表示成功で終了 ==="
else
    log_message "=== コミットウィンドウ表示失敗で終了 ==="
    log_message "代替手順: 手動で'c'キーを押してコミット画面を開いてください"
    log_message "生成されたコミットメッセージは既にテンプレートに設定済みです"
fi

# コミット完了後のクリーンアップ処理
log_message "=== ポストコミットクリーンアップ開始 ==="

# 成功時のみクリーンアップを実行
if [[ "$success" == "true" ]]; then
    # 設定可能な待機時間（環境変数で設定可能、デフォルト500ms）
    cleanup_delay_ms="${AI_COMMIT_CLEANUP_DELAY_MS:-500}"
    log_message "成功時クリーンアップ: ${cleanup_delay_ms}ms待機後に実行"
    
    # pure Bashで秒数を計算（bcなしで）
    delay_seconds="$((cleanup_delay_ms / 1000))"
    delay_milliseconds="$((cleanup_delay_ms % 1000))"
    # 小数点形式で結合
    if [[ $delay_milliseconds -eq 0 ]]; then
        sleep_time="${delay_seconds}"
    else
        sleep_time="${delay_seconds}.$(printf "%03d" $delay_milliseconds)"
    fi
    
    sleep "$sleep_time"
    
    # commit.templateをクリア
    git config --unset commit.template 2>/dev/null || true
    log_message "git commit.templateをクリア"

    # テンプレートファイルを削除
    template_file="${AI_COMMIT_TEMPLATE_FILE:-/tmp/ai-commit-template.txt}"
    rm -f "$template_file" 2>/dev/null || true
    log_message "テンプレートファイルを削除: $template_file"
else
    log_message "失敗時: テンプレート設定とファイルを保持（手動リトライ用）"
fi

log_message "=== ポストコミットクリーンアップ完了 ==="

if [[ "$success" == "true" ]]; then
    exit 0
else
    exit 1
fi