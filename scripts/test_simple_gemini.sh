#!/bin/bash
# 簡単なGemini CLIテスト

set -euo pipefail

echo "=== 簡単なGemini CLIテスト ==="
echo

# APIキー確認
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "エラー: GEMINI_API_KEYが設定されていません"
    exit 1
fi

echo "成功: APIキーが設定されています"
echo

# 実際のテスト - 簡単なプロンプト
echo "=== Gemini CLI実行 ==="
echo "コマンド: echo プロンプト | gemini"

simple_prompt="HTTPサーバーファイルを追加するコミットメッセージを30文字で生成してください"

if result=$(echo "$simple_prompt" | gemini 2>&1); then
    echo "成功!"
    echo
    echo "生成されたメッセージ:"
    echo "$result"
    echo
    
    # 基本的な後処理
    processed=$(echo "$result" | grep -v "Loaded cached credentials" | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    echo "後処理後:"
    echo "$processed"
    
    if [[ -n "$processed" ]]; then
        echo "成功: 有効なメッセージが生成されました"
    else
        echo "エラー: 空のメッセージです"
    fi
else
    echo "エラー: 失敗"
    echo "詳細: $result"
fi

echo
echo "=== テスト完了 ==="