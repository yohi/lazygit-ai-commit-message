# Lazygit統合セットアップガイド

## 🎯 概要

AI Commit GeneratorをLazygitと統合し、Ctrl+Gキーでシームレスにコミットメッセージを生成できるようになりました。

## ✨ 新機能

- **Lazygit内での実行**: `subprocess: true`ではなく`output: 'popup'`を使用してLazygitを閉じずに実行
- **クリーンな出力**: Lazygitモード専用のUI（絵文字とプログレス表示）
- **エラーログ分離**: 実行時ログは`/tmp/ai-commit-generator.log`に記録

## 🔧 セットアップ手順

### 1. Lazygit設定ファイルに統合

以下の設定を`~/.config/lazygit/config.yml`に追加してください：

```yaml
customCommands:
  - key: '<c-g>'
    context: 'files'
    command: 'ai-commit-generator --lazygit-mode'
    description: 'AIコミットメッセージ生成'
    output: 'popup'
    prompts:
      - type: 'confirm'
        title: 'AIコミットメッセージ生成'
        body: '生成AIがコミットメッセージを作成します。続行しますか？'
  - key: '<c-x>'
    context: 'files'
    command: 'ai-commit-generator --check-env'
    description: '環境変数チェック'
    output: 'popup'
```

### 2. 設定ファイルをコピー（自動）

```bash
# プロジェクトの設定をLazygitに統合
cp config/lazygit.yml ~/.config/lazygit/config.yml
```

## 🚀 使用方法

### Lazygit内での操作

1. **Lazygitを起動**
   ```bash
   lazygit
   ```

2. **ファイルをステージ**
   - ファイル一覧画面で変更したいファイルを選択
   - `Space`キーでステージ

3. **AIコミットメッセージ生成**
   - `Ctrl+G`を押す
   - 確認ダイアログで`Enter`
   - AIが生成したメッセージがポップアップで表示される

4. **コミット実行**
   - 生成されたメッセージを確認
   - 通常のコミット手順でコミット実行

### コマンドライン操作

```bash
# Lazygitモードでテスト実行
ai-commit-generator --lazygit-mode

# 通常モード（従来通り）
ai-commit-generator

# 環境チェック
ai-commit-generator --check-env
```

## 📋 動作確認

### 1. 基本動作テスト

```bash
# テストファイルを作成してステージ
echo "test change" > test.txt
git add test.txt

# Lazygitモードで実行
ai-commit-generator --lazygit-mode
```

### 2. Lazygit内でのテスト

1. Lazygitを起動
2. ファイルをステージ
3. `Ctrl+G`でAI生成をテスト

## 🔍 出力例

Lazygitモードでの実行結果：

```
🤖 AIコミットメッセージを生成中...

📊 ステージされたファイルを分析中...
✅ ファイル分析完了

🧠 Gemini AIでコミットメッセージを生成中...
✅ コミットメッセージ生成完了

📝 生成されたコミットメッセージ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
feat: テストファイルを追加
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

このメッセージをコミットに使用できます。
```

## 🛠️ トラブルシューティング

### よくある問題

1. **Lazygitが閉じてしまう**
   - `subprocess: true`が設定されていないか確認
   - `output: 'popup'`が正しく設定されているか確認

2. **ログが出力に混じる**
   - `--lazygit-mode`オプションが使用されているか確認
   - ログは`/tmp/ai-commit-generator.log`に記録されます

3. **Gemini CLIエラー**
   ```bash
   # 環境変数確認
   ai-commit-generator --check-env
   
   # API接続テスト
   ai-commit-generator --test-gemini
   ```

### デバッグ

```bash
# ログファイル確認
tail -f /tmp/ai-commit-generator.log

# 詳細デバッグ
ai-commit-generator --lazygit-mode --log-level debug
```

## 📚 関連ファイル

- `config/lazygit.yml`: Lazygit統合設定
- `ai-commit-generator`: メインスクリプト（--lazygit-modeオプション追加）
- `/tmp/ai-commit-generator.log`: Lazygitモード実行ログ

## 🎉 完了

これでLazygit内でCtrl+Gを押すだけで、AIが生成したコミットメッセージを確認できるようになりました！