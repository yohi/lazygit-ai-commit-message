#!/bin/bash
# AI生成後の自動コミットキー送信スクリプト

# エラーハンドリングを緩和（xdotoolエラーでスクリプトが止まらないように）
set -uo pipefail

# ログファイル
LOG_FILE="/tmp/auto_commit_key.log"

# ログ関数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

log_message "自動コミットキー送信開始"

# popupが閉じられるまで待機
sleep 3
log_message "待機完了、キー送信を開始"

# キー送信の試行
success=false
max_attempts=10
attempt=1

while [[ "$success" == "false" && "$attempt" -le "$max_attempts" ]]; do
    log_message "試行 $attempt/$max_attempts"
    
    if [[ -n "${TMUX:-}" ]]; then
        log_message "tmux環境でキー送信"
        if tmux send-keys c 2>/dev/null; then
            success=true
            log_message "tmuxキー送信成功"
        fi
    elif command -v xdotool >/dev/null 2>&1; then
        log_message "xdotool環境でキー送信"
        
        # 全ウィンドウを検索してデバッグ
        log_message "ウィンドウ検索を開始"
        local all_windows=""
        if all_windows=$(xdotool search --name ".*" 2>/dev/null | head -10); then
            log_message "検出されたウィンドウ一覧: $all_windows"
        else
            log_message "ウィンドウ検索に失敗"
        fi
        
        # lazygitウィンドウを複数の方法で検索
        log_message "lazygitウィンドウ検索を開始"
        local lazygit_windows=""
        if lazygit_windows=$(xdotool search --name "lazygit" 2>/dev/null) && [[ -n "$lazygit_windows" ]]; then
            log_message "lazygitウィンドウ検出: $lazygit_windows"
        else
            log_message "lazygitウィンドウが見つかりません。ターミナルウィンドウを検索中..."
            # lazygitが見つからない場合、ターミナル名で検索
            if lazygit_windows=$(xdotool search --class "gnome-terminal" 2>/dev/null) && [[ -n "$lazygit_windows" ]]; then
                log_message "gnome-terminalウィンドウ検出: $lazygit_windows"
            elif lazygit_windows=$(xdotool search --class "Terminal" 2>/dev/null) && [[ -n "$lazygit_windows" ]]; then
                log_message "Terminalウィンドウ検出: $lazygit_windows"
            elif lazygit_windows=$(xdotool search --class "terminal" 2>/dev/null) && [[ -n "$lazygit_windows" ]]; then
                log_message "terminalウィンドウ検出: $lazygit_windows"
            else
                log_message "ターミナルウィンドウも見つかりません"
            fi
        fi
        
        if [[ -n "$lazygit_windows" ]]; then
            local window_id=$(echo "$lazygit_windows" | head -1)
            log_message "ターゲットウィンドウID: $window_id"
            
            # ウィンドウ情報を取得
            local window_name=$(xdotool getwindowname "$window_id" 2>/dev/null || echo "unknown")
            log_message "ウィンドウ名: $window_name"
            
            # ウィンドウをアクティベートしてキーを送信
            if xdotool windowactivate "$window_id" 2>/dev/null; then
                log_message "ウィンドウアクティベート成功"
                sleep 0.5
                if xdotool key --window "$window_id" c 2>/dev/null; then
                    success=true
                    log_message "xdotoolキー送信成功 (ウィンドウID: $window_id)"
                else
                    log_message "キー送信失敗"
                fi
            else
                log_message "ウィンドウアクティベート失敗"
            fi
        else
            log_message "対象ウィンドウが見つかりません"
        fi
        
        # 失敗した場合はフォーカスウィンドウに直接送信
        if [[ "$success" == "false" ]]; then
            log_message "フォーカスウィンドウに直接送信を試行"
            local active_window=$(xdotool getactivewindow 2>/dev/null || echo "none")
            log_message "アクティブウィンドウ: $active_window"
            
            if xdotool key --clearmodifiers c 2>/dev/null; then
                success=true
                log_message "フォーカスウィンドウへのキー送信成功"
            else
                log_message "フォーカスウィンドウへのキー送信失敗"
            fi
        fi
    fi
    
    if [[ "$success" == "false" ]]; then
        log_message "試行 $attempt 失敗、1秒待機"
        sleep 1
        attempt=$((attempt + 1))
    fi
done

if [[ "$success" == "true" ]]; then
    log_message "キー送信成功でスクリプト終了"
else
    log_message "全ての試行が失敗、スクリプト終了"
fi