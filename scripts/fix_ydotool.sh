#!/bin/bash
# ydotool権限問題修正スクリプト

set -euo pipefail

echo "🔧 ydotool権限問題修正スクリプト開始"

# 既存のydotooldプロセスを停止
echo "1. 既存のydotooldプロセスを停止中..."
sudo pkill -f ydotoold 2>/dev/null || true

# 既存のソケットを削除
echo "2. 既存のソケットを削除中..."
sudo rm -f /tmp/.ydotool_socket

# 少し待機
sleep 1

# ydotooldをバックグラウンドで起動
echo "3. ydotooldをバックグラウンドで起動中..."
sudo ydotoold &

# ソケットが作成されるまで待機
echo "4. ソケット作成を待機中..."
for i in {1..10}; do
    if [[ -e /tmp/.ydotool_socket ]]; then
        echo "   ソケットが作成されました (${i}秒後)"
        break
    fi
    sleep 1
done

# ソケットの権限を設定
if [[ -e /tmp/.ydotool_socket ]]; then
    echo "5. ソケット権限を設定中..."
    if getent group input >/dev/null 2>&1; then
        sudo chgrp input /tmp/.ydotool_socket || true
        sudo chmod 660 /tmp/.ydotool_socket
        echo "   ✅ ソケット権限を660 (group: input) に設定しました"
    else
        echo "   ⚠️ 'input' グループが見つかりません。最小権限運用のため 'input' グループの作成/付与を検討してください" >&2
        sudo chmod 660 /tmp/.ydotool_socket
        echo "   ✅ 暫定で 660 を適用しました"
    fi
    
    # 権限確認
    echo "6. 権限確認:"
    ls -la /tmp/.ydotool_socket
    
    # 動作テスト
    echo "7. ydotool動作テスト:"
    if ydotool key --help >/dev/null 2>&1; then
        echo "   ✅ ydotoolが正常に動作しています"
        echo "   🎉 修正完了！自動コミットウィンドウが使用可能になりました"
    else
        echo "   ❌ まだydotoolが動作しません"
        echo "   エラー詳細:"
        ydotool key --help 2>&1 | head -3
    fi
else
    echo "❌ ソケットの作成に失敗しました"
    echo "ydotooldが正常に起動していない可能性があります"
    exit 1
fi

echo ""
echo "📋 設定結果:"
echo "   ydotooldプロセス: $(pgrep -f ydotoold >/dev/null && echo "実行中" || echo "停止中")"
echo "   ソケット存在: $(ls /tmp/.ydotool_socket >/dev/null 2>&1 && echo "あり" || echo "なし")"
echo "   ydotool動作: $(ydotool key --help >/dev/null 2>&1 && echo "OK" || echo "NG")"