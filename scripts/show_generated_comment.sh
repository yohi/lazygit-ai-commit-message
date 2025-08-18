#!/bin/bash
# 🔍 AI生成コメント表示スクリプト

if [ -f "/tmp/lazygit_ai_commit_message.txt" ]; then
  ACTION=""
  if [ -f "/tmp/lazygit_selected_action.txt" ]; then
    ACTION=$(cat /tmp/lazygit_selected_action.txt)
  fi
  
  echo "✅ AI生成完了"
  echo ""
  echo "🎯 選択された操作: $ACTION"
  echo ""
  echo "📝 生成されたAIコミットメッセージ:"
  echo "┌─────────────────────────────────────────┐"
  echo "│ $(cat /tmp/lazygit_ai_commit_message.txt | head -1)"
  echo "└─────────────────────────────────────────┘"
  echo ""
  echo "🧠 AI情報: Gemini 2.5 Flash"
  echo "📊 ステージされた変更:"
  git diff --cached --stat | sed 's/^/  • /'
else
  echo "❌ AI生成されたコメントが見つかりません"
  echo "💡 まず Ctrl+G でAI生成を実行してください"
fi