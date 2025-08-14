#!/bin/bash
# Gemini CLI テストスクリプト

set -euo pipefail

echo "=== Gemini CLI テスト ==="
echo

# Gemini CLIの存在確認
echo "1. Gemini CLI の確認"
if command -v gemini >/dev/null 2>&1; then
    echo "✅ Gemini CLI が見つかりました: $(which gemini)"
else
    echo "❌ Gemini CLI が見つかりません"
    exit 1
fi
echo

# バージョン確認
echo "2. バージョン情報"
gemini --version 2>/dev/null || gemini -v 2>/dev/null || echo "バージョン情報が取得できません"
echo

# ヘルプ確認
echo "3. ヘルプ情報"
echo "--- gemini --help ---"
gemini --help 2>&1 | head -20
echo
echo "利用可能なサブコマンド:"
gemini --help 2>&1 | grep -E "^\s*(generate|text|chat)" || echo "該当するサブコマンドが見つかりません"
echo

# API キー確認
echo "4. API キー設定"
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    echo "✅ GEMINI_API_KEY が設定されています (長さ: ${#GEMINI_API_KEY} 文字)"
    echo "先頭: ${GEMINI_API_KEY:0:10}..."
else
    echo "❌ GEMINI_API_KEY が設定されていません"
    echo "設定方法: export GEMINI_API_KEY=\"your-api-key\""
fi
echo

# 簡単なテスト実行
echo "5. 簡単なテスト実行"
test_prompt="こんにちは"

echo "テストプロンプト: $test_prompt"
echo

# パターン1: --prompt オプション
echo "パターン1: gemini --prompt"
if gemini --prompt="$test_prompt" 2>&1; then
    echo "✅ --prompt オプションが成功しました"
else
    echo "❌ --prompt オプションが失敗しました (終了コード: $?)"
fi
echo

# パターン2: 標準入力
echo "パターン2: echo | gemini"
if echo "$test_prompt" | gemini 2>&1; then
    echo "✅ 標準入力が成功しました"
else
    echo "❌ 標準入力が失敗しました (終了コード: $?)"
fi
echo

# パターン3: モデル指定
echo "パターン3: gemini --model指定"
if gemini --prompt="$test_prompt" --model="gemini-pro" 2>&1; then
    echo "✅ モデル指定が成功しました"
else
    echo "❌ モデル指定が失敗しました (終了コード: $?)"
fi
echo

echo "=== テスト完了 ==="