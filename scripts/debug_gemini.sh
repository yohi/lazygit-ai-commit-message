#!/bin/bash
# Gemini CLI デバッグスクリプト（Docker環境対応）

set -euo pipefail

echo "=== Docker環境でのGemini CLI デバッグ ==="
echo

# 環境情報
echo "1. 環境情報"
echo "- OS: $(uname -a)"
echo "- Container ID: $(hostname)"
echo "- Current Dir: $(pwd)"
echo "- User: $(whoami)"
echo

# Gemini CLI確認
echo "2. Gemini CLI バイナリ確認"
echo "- パス: $(which gemini || echo 'NOT FOUND')"
echo "- バージョン: $(gemini --version 2>/dev/null || echo 'バージョン取得失敗')"
echo "- ファイル情報: $(ls -la $(which gemini) 2>/dev/null || echo 'ファイル情報取得失敗')"
echo

# API キー確認
echo "3. API キー確認"
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    echo "- 設定状況: ✅ 設定済み"
    echo "- 長さ: ${#GEMINI_API_KEY} 文字"
    echo "- 先頭10文字: ${GEMINI_API_KEY:0:10}..."
    echo "- 末尾4文字: ...${GEMINI_API_KEY: -4}"
else
    echo "- 設定状況: ❌ 未設定"
    echo "設定方法: export GEMINI_API_KEY=\"your-api-key\""
fi
echo

# ネットワーク接続確認
echo "4. ネットワーク接続確認"
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "- google.com: ✅ 接続可能"
else
    echo "- google.com: ❌ 接続失敗"
fi

if ping -c 1 generativelanguage.googleapis.com >/dev/null 2>&1; then
    echo "- generativelanguage.googleapis.com: ✅ 接続可能"
else
    echo "- generativelanguage.googleapis.com: ❌ 接続失敗"
fi
echo

# Gemini CLI 直接テスト
echo "5. Gemini CLI 直接テスト"
test_prompt="Hello"

echo "テスト1: gemini --prompt"
echo "コマンド: gemini --prompt=\"$test_prompt\""
echo "出力:"
if timeout 10 gemini --prompt="$test_prompt" 2>&1; then
    echo "結果: ✅ 成功"
else
    echo "結果: ❌ 失敗 (終了コード: $?)"
fi
echo

echo "テスト2: echo | gemini"
echo "コマンド: echo \"$test_prompt\" | gemini"
echo "出力:"
if echo "$test_prompt" | timeout 10 gemini 2>&1; then
    echo "結果: ✅ 成功"
else
    echo "結果: ❌ 失敗 (終了コード: $?)"
fi
echo

echo "テスト3: モデル指定"
echo "コマンド: gemini --prompt=\"$test_prompt\" --model=\"gemini-pro\""
echo "出力:"
if timeout 10 gemini --prompt="$test_prompt" --model="gemini-pro" 2>&1; then
    echo "結果: ✅ 成功"
else
    echo "結果: ❌ 失敗 (終了コード: $?)"
fi
echo

# ログファイルがあるかチェック
echo "6. ログ確認"
if [[ -f ~/.gemini/logs/gemini.log ]]; then
    echo "- Geminiログファイル発見"
    echo "最新のログエントリ:"
    tail -5 ~/.gemini/logs/gemini.log || echo "ログ読み取り失敗"
else
    echo "- Geminiログファイルなし"
fi
echo

# 環境変数確認
echo "7. 関連環境変数"
echo "- HTTP_PROXY: ${HTTP_PROXY:-未設定}"
echo "- HTTPS_PROXY: ${HTTPS_PROXY:-未設定}"
echo "- NO_PROXY: ${NO_PROXY:-未設定}"
echo "- GEMINI_API_KEY: ${GEMINI_API_KEY:+設定済み}"
echo

echo "=== デバッグ完了 ==="