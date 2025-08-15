#!/bin/bash
# 環境変数チェックスクリプト

echo "=== 環境変数チェック ==="
echo "実行環境: $0"
echo "親プロセス: $(ps -o comm= -p $PPID 2>/dev/null || echo 'unknown')"
echo "現在のユーザー: $(whoami)"
echo "現在のディレクトリ: $(pwd)"
echo

echo "重要な環境変数:"
echo "- GEMINI_API_KEY: ${GEMINI_API_KEY:+設定済み}"
echo "- PATH: $PATH"
echo "- HOME: $HOME"
echo "- SHELL: $SHELL"
echo

echo "Gemini CLI確認:"
echo "- which gemini: $(which gemini 2>/dev/null || echo 'not found')"
echo "- gemini version: $(gemini --version 2>/dev/null || echo 'version error')"
echo

echo "簡単なテスト:"
if echo "test" | gemini >/dev/null 2>&1; then
    echo "- Gemini CLI: ✅ 動作可能"
else
    echo "- Gemini CLI: ❌ 動作不可"
fi

echo
echo "=== チェック完了 ==="