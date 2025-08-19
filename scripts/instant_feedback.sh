#!/bin/bash
# 🚀 確認ダイアログ専用スクリプト（ネイティブスピナー用）

# Lazygitネイティブスピナーをトリガーするため、直接実行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/ai_commit_integrated.sh" display "${@}"
