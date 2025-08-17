#!/bin/bash
# 手動キー送信テストスクリプト

echo "=== 手動ydotoolキー送信テスト ==="
echo ""
echo "準備:"
echo "1. lazygitを起動してください"
echo "2. ファイルをステージしてください"
echo "3. ファイルペイン（左側）がフォーカスされていることを確認してください"
echo "4. このスクリプトを実行してください"
echo ""

read -p "準備ができたらEnterキーを押してください..."

echo "3秒後にcキーを送信します..."
for i in 3 2 1; do
    echo "$i..."
    sleep 1
done

echo "cキーを送信中..."
ydotool key c

echo ""
echo "キー送信完了しました。"
echo "lazygitでコミット画面が開きましたか？"