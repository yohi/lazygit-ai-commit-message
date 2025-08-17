#!/bin/bash
# フォーカス問題の解決策テストスクリプト

echo "=== フォーカス問題解決策テスト ==="
echo ""
echo "準備: lazygitを起動してファイルをステージしてください"
read -p "準備完了後、Enterキーを押してください..."

echo ""
echo "解決策1: ウィンドウアクティベート後のキー送信"
echo "3秒後に実行..."
sleep 3

# 解決策1: lazygitウィンドウを明示的にアクティベート
echo "lazygitウィンドウを検索してアクティベート中..."
if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -a lazygit 2>/dev/null || echo "wmctrlでのアクティベート失敗"
fi

sleep 1
echo "キー送信実行..."
ydotool key c
echo "解決策1完了。コミット画面が開きましたか？"
read -p "結果 (y/n): " result1

if [[ "$result1" == "y" ]]; then
    echo "✅ 解決策1で成功！"
    exit 0
fi

echo ""
echo "解決策2: キーコード指定での送信"
echo "3秒後に実行..."
sleep 3

echo "キーコード46でキー送信..."
ydotool key 46:1 46:0  # key down, key up
echo "解決策2完了。コミット画面が開きましたか？"
read -p "結果 (y/n): " result2

if [[ "$result2" == "y" ]]; then
    echo "✅ 解決策2で成功！"
    exit 0
fi

echo ""
echo "解決策3: 複数回キー送信"
echo "3秒後に実行..."
sleep 3

echo "短い間隔で3回キー送信..."
for i in {1..3}; do
    ydotool key c
    sleep 0.2
done
echo "解決策3完了。コミット画面が開きましたか？"
read -p "結果 (y/n): " result3

if [[ "$result3" == "y" ]]; then
    echo "✅ 解決策3で成功！"
    exit 0
fi

echo ""
echo "解決策4: マウスクリック後のキー送信"
echo "3秒後に実行..."
sleep 3

echo "lazygitウィンドウをクリックしてからキー送信..."
# 画面中央をクリック（lazygitウィンドウがある想定）
ydotool click 40:400 40:300  # 仮の座標
sleep 0.5
ydotool key c
echo "解決策4完了。コミット画面が開きましたか？"
read -p "結果 (y/n): " result4

if [[ "$result4" == "y" ]]; then
    echo "✅ 解決策4で成功！"
    exit 0
fi

echo ""
echo "❌ すべての解決策が失敗しました"
echo "Waylandの制限により、ydotoolでは解決できない可能性があります"