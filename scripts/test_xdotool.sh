#!/bin/bash
# xdotoolの基本動作テスト

LOG_FILE="/tmp/xdotool_test.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_message "=== xdotoolテスト開始 ==="

# xdotoolの存在確認
if command -v xdotool >/dev/null 2>&1; then
    log_message "✅ xdotoolが利用可能"
else
    log_message "❌ xdotoolが見つかりません"
    exit 1
fi

# アクティブウィンドウの取得テスト
log_message "アクティブウィンドウを取得中..."
if active_window=$(xdotool getactivewindow 2>&1); then
    log_message "✅ アクティブウィンドウ: $active_window"
    
    # ウィンドウ名を取得
    if window_name=$(xdotool getwindowname "$active_window" 2>&1); then
        log_message "✅ ウィンドウ名: $window_name"
    else
        log_message "⚠️ ウィンドウ名の取得に失敗: $window_name"
    fi
else
    log_message "❌ アクティブウィンドウの取得に失敗: $active_window"
fi

# キー送信テスト（無害なキー）
log_message "キー送信テスト開始（5秒後にスペースキーを送信）..."
sleep 5
if xdotool key space 2>&1; then
    log_message "✅ キー送信成功"
else
    log_message "❌ キー送信失敗"
fi

log_message "=== xdotoolテスト完了 ==="