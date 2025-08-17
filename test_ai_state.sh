#!/bin/bash
# AI生成後の状態確認スクリプト

echo "=== AI生成後の状態確認テスト ==="
echo ""
echo "手順:"
echo "1. lazygitを起動してファイルをステージ"
echo "2. Ctrl+G でAI生成実行"
echo "3. AI生成完了後、このスクリプトを実行"
echo ""

read -p "AI生成が完了したらEnterキーを押してください..."

echo "現在の状況を確認中..."
echo ""

# lazygitプロセス確認
echo "1. lazygitプロセス:"
if pgrep lazygit >/dev/null; then
    echo "   ✅ lazygit実行中 (PID: $(pgrep lazygit))"
else
    echo "   ❌ lazygitが実行されていません"
fi

# ydotool動作確認
echo ""
echo "2. ydotool動作確認:"
if ydotool key --help >/dev/null 2>&1; then
    echo "   ✅ ydotool正常動作"
else
    echo "   ❌ ydotool動作不正常"
fi

# コミットテンプレート確認
echo ""
echo "3. コミットテンプレート確認:"
if [[ -f /tmp/ai-commit-template.txt ]]; then
    echo "   ✅ コミットテンプレートあり"
    echo "   内容: $(head -1 /tmp/ai-commit-template.txt)"
else
    echo "   ❌ コミットテンプレートなし"
fi

echo ""
echo "5秒後にcキーを送信します..."
for i in 5 4 3 2 1; do
    echo "$i..."
    sleep 1
done

echo "cキー送信実行..."
ydotool key c

echo ""
echo "結果: コミット画面が開きましたか？ (y/n)"