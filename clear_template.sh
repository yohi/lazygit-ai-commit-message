#!/bin/bash
# コミットテンプレートをクリアするスクリプト

set -euo pipefail

echo "🧹 コミットテンプレートをクリア中..."

# Gitのコミットテンプレート設定を削除
if git config --get commit.template >/dev/null 2>&1; then
    git config --unset commit.template
    echo "✅ Gitコミットテンプレート設定を削除しました"
else
    echo "ℹ️  コミットテンプレート設定は既にありません"
fi

# 一時テンプレートファイルを削除
if [[ -f "/tmp/ai-commit-template.txt" ]]; then
    rm -f "/tmp/ai-commit-template.txt"
    echo "✅ 一時テンプレートファイルを削除しました"
else
    echo "ℹ️  一時テンプレートファイルは既にありません"
fi

echo "🎉 クリーンアップ完了！"