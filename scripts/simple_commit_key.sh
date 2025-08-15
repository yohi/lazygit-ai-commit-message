#!/bin/bash
# シンプルな自動コミットキー送信スクリプト

LOG_FILE="/tmp/simple_commit_key.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

log_message "=== シンプルキー送信開始 ==="

# 待機
sleep 3
log_message "待機完了、キー送信開始"

# シンプルなキー送信（最もシンプルな方法）
success=false

if [[ -n "${TMUX:-}" ]]; then
    log_message "tmux環境を検出"
    if tmux send-keys c 2>/dev/null; then
        success=true
        log_message "tmuxキー送信成功"
    else
        log_message "tmuxキー送信失敗"
    fi
elif command -v xdotool >/dev/null 2>&1; then
    log_message "xdotool環境を検出"
    
    # 最もシンプルな方法：現在のフォーカスウィンドウに直接送信
    if xdotool key c 2>/dev/null; then
        success=true
        log_message "xdotool直接キー送信成功"
    else
        log_message "xdotool直接キー送信失敗"
        
        # フォールバック：modifierをクリアしてから送信
        if xdotool key --clearmodifiers c 2>/dev/null; then
            success=true
            log_message "xdotoolクリアmodifierキー送信成功"
        else
            log_message "xdotoolクリアmodifierキー送信失敗"
        fi
    fi
else
    log_message "tmuxもxdotoolも利用できません"
fi

if [[ "$success" == "true" ]]; then
    log_message "=== キー送信成功で終了 ==="
else
    log_message "=== キー送信失敗で終了 ==="
fi