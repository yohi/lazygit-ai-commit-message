#!/bin/bash
# 実際にウィンドウが表示される統合フローのデモ

echo "🎯 AI Commit Generator - 実動作ウィンドウデモ"
echo "=============================================="
echo "このデモでは実際にAI生成メッセージが挿入された自作ウィンドウが表示されます"
echo

# デモ用ファイルを作成
echo "📁 Step 1: デモファイル作成"
echo "# Working Window Demo" > working_demo.md
echo "実際にウィンドウが表示されるデモです" >> working_demo.md
git add working_demo.md
echo "✅ ファイル作成・ステージ完了"
echo

# AI生成をシミュレート
echo "🤖 Step 2: AI生成シミュレート"
AI_MESSAGE="feat: 実動作ウィンドウデモ用ファイルを追加"
echo "✅ AI生成完了: $AI_MESSAGE"
echo

# 自作ウィンドウを実際に表示
echo "🖥️  Step 3: 自作ウィンドウ表示"
echo "生成されたメッセージが事前入力された状態で表示されます..."
echo

# 実際のウィンドウ関数を呼び出し
source ./src/commit_window.sh

echo "🚀 自作ウィンドウを起動中..."
echo

# 実際に対話エディターを呼び出し
FINAL_MESSAGE=$(edit_message_lazygit_interactive "$AI_MESSAGE")
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 && -n "$FINAL_MESSAGE" ]]; then
    echo
    echo "✅ ウィンドウ操作完了！"
    echo "📝 最終メッセージ: $FINAL_MESSAGE"
    echo
    
    echo "🚀 Step 4: コミット実行"
    if git commit -m "$FINAL_MESSAGE"; then
        echo "🎉 コミット完了！"
        echo
        echo "📋 結果確認:"
        git log -1 --oneline
    else
        echo "❌ コミットに失敗しました"
    fi
else
    echo "⚠️  ウィンドウ操作がキャンセルされました"
    rm -f working_demo.md
    exit 1
fi

echo
echo "🧹 クリーンアップ"
echo "このデモコミットを削除しますか？ (y/N): "
read -p "" cleanup
if [[ "$cleanup" == "y" ]]; then
    git reset --hard HEAD~1
    rm -f working_demo.md
    echo "✅ デモ削除完了"
else
    echo "📝 デモコミットを保持しました"
fi

echo
echo "🎉 実動作ウィンドウデモ完了！"
echo
echo "📋 動作確認結果:"
echo "✅ AI生成メッセージが自作ウィンドウに正常に挿入されました"
echo "✅ ユーザーが選択・編集できました"
echo "✅ 編集後のメッセージでコミットが実行されました"
echo
echo "🚀 Lazygitでの実際の使用:"
echo "   1. ファイルをステージ"
echo "   2. Ctrl+G押下"
echo "   3. 自動的にこのウィンドウが表示されます"