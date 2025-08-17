# 🖥️ AI Commit Generator - カスタムウィンドウ機能ガイド

## 📋 概要

AI Commit Generatorに新しく追加されたカスタムウィンドウ機能は、AI生成されたコミットメッセージを専用のTUI（Terminal User Interface）ウィンドウで表示・編集できる機能です。

### 🎯 主な特徴

- **独立したコミットウィンドウ**: lazygitの既存ウィンドウとは独立したTUI
- **AI生成メッセージの事前入力**: 生成されたメッセージが自動的に表示
- **ユーザー編集可能**: メッセージを自由に編集・修正
- **複数エディター対応**: dialog, whiptail, nano/viに対応
- **確認ダイアログ**: コミット前に最終確認

## 🚀 使用方法

### 1. Lazygit内からの実行

```bash
# Lazygitで files コンテキストにて
Ctrl+W  # カスタムウィンドウモードを起動
```

### 2. コマンドラインからの直接実行

```bash
# カスタムウィンドウモード
ai-commit-generator --custom-window

# 生成のみ（ウィンドウ表示なし）
ai-commit-generator --generate-only
```

### 3. API関数としての利用

```bash
# スクリプト内で利用
source ai-commit-generator/src/commit_window.sh

# AI生成メッセージの取得
ai_message=$(ai-commit-generator --generate-only)

# カスタムウィンドウでの編集
edited_message=$(show_ai_commit_window "$ai_message")

# 確認してコミット
confirm_and_commit "$edited_message"
```

## 🔧 設定

### Lazygit設定

`~/.config/lazygit/config.yml` に以下を追加:

```yaml
customCommands:
  - key: "<c-w>"
    context: "files"
    command: "ai-commit-generator --custom-window"
    description: "AI生成 + カスタムTUIウィンドウ"
    output: "logWithPty"
    stream: false
    prompts:
      - type: "confirm"
        title: "AI生成 + カスタムウィンドウ"
        body: "AIが生成したメッセージをカスタムウィンドウで編集します。続行しますか？"
```

### 環境要件

#### 必須
- `git`: Gitリポジトリ操作
- `tput`: ターミナル制御
- `bash`: スクリプト実行環境

#### 推奨（いずれか1つ）
- `dialog`: 高機能なTUIダイアログ
- `whiptail`: 軽量なTUIダイアログ  
- `nano` または `vi`: テキストエディター

## 🖥️ ウィンドウの操作方法

### dialogエディター使用時
- **Tab**: フィールド間移動
- **Enter**: 選択/確定
- **Esc**: キャンセル
- **Ctrl+Enter**: OK（適用）

### whiptailエディター使用時
- **Tab**: ボタン間移動
- **Enter**: 選択/確定
- **Esc**: キャンセル

### nano/viエディター使用時
- 通常のエディター操作
- **Ctrl+X** (nano) / **:wq** (vi): 保存して終了
- **Ctrl+C** (nano) / **:q!** (vi): キャンセル

## 📁 ファイル構造

```
ai-commit-generator/
├── src/
│   └── commit_window.sh       # カスタムウィンドウ実装
├── scripts/
│   └── test_custom_window.sh  # テストスクリプト
├── config/
│   └── lazygit.yml           # Lazygit設定（Ctrl+W追加）
└── ai-commit-generator       # メインスクリプト（新オプション追加）
```

## 🧪 テスト

### テストスクリプトの実行

```bash
# カスタムウィンドウ機能のテスト
./scripts/test_custom_window.sh

# デモモードでの動作確認
./src/commit_window.sh --demo
```

### 手動テスト手順

1. **テスト環境の準備**
   ```bash
   echo "test content" > test_file.txt
   git add test_file.txt
   ```

2. **生成のみモードのテスト**
   ```bash
   ai-commit-generator --generate-only
   ```

3. **カスタムウィンドウモードのテスト**
   ```bash
   ai-commit-generator --custom-window
   ```

4. **クリーンアップ**
   ```bash
   rm test_file.txt
   git reset HEAD test_file.txt
   ```

## 🔄 フロー図

```
Ctrl+W押下
    ↓
Lazygit確認ダイアログ
    ↓ (Yes)
AI生成処理
    ↓
カスタムウィンドウ表示
    ↓
ユーザー編集
    ↓
確認ダイアログ
    ↓ (Yes)
Gitコミット実行
    ↓
完了
```

## 🆚 既存モードとの比較

| モード | キー | 特徴 | 用途 |
|--------|------|------|------|
| **Lazygitモード** | `Ctrl+G` | 結果をログ表示 | 確認のみ |
| **自動コミット** | `Ctrl+A` | 既存UI利用 | 標準的な利用 |
| **直接コミット** | `Alt+C` | 確認後即コミット | 高速処理 |
| **カスタムウィンドウ** | `Ctrl+W` | 専用UI | 詳細編集 |

## 💡 使用例

### 1. 詳細なコミットメッセージの作成

長いコミットメッセージや複数行メッセージを作成する場合、カスタムウィンドウを使用することで快適に編集できます。

### 2. スクリプトからの自動化

```bash
#!/bin/bash
# 自動コミットスクリプト例

# ステージング
git add .

# AI生成
message=$(ai-commit-generator --generate-only)

# カスタムウィンドウで編集
if edited_message=$(show_ai_commit_window "$message"); then
    echo "編集されたメッセージでコミットを実行"
    git commit -m "$edited_message"
else
    echo "コミットがキャンセルされました"
fi
```

### 3. CI/CDでの利用

```bash
# プリコミットフックでの利用例
if [[ -n "$(git diff --cached)" ]]; then
    # 生成のみモードで自動メッセージ生成
    auto_message=$(ai-commit-generator --generate-only)
    echo "Suggested commit message: $auto_message"
fi
```

## 🐛 トラブルシューティング

### よくある問題

#### 1. ウィンドウが表示されない
```bash
# 依存関係チェック
command -v dialog || echo "dialog not found"
command -v whiptail || echo "whiptail not found"
command -v nano || echo "nano not found"
```

#### 2. エディターが起動しない
```bash
# ターミナル互換性チェック
tput cols && echo "tput working" || echo "tput not working"
```

#### 3. コミットに失敗する
```bash
# Git状態チェック
git status
git diff --cached
```

### ログ確認

```bash
# 詳細ログ確認
tail -f /tmp/ai-commit-generator.log

# デバッグモード実行
ai-commit-generator --custom-window --log-level debug
```

## 🔮 今後の拡張予定

- **テーマカスタマイズ**: ウィンドウの色やレイアウト設定
- **プラグインシステム**: カスタムエディター追加
- **履歴機能**: 過去のコミットメッセージ履歴
- **テンプレート機能**: 定型コミットメッセージテンプレート
- **マルチライン編集**: より高度なテキスト編集機能

---

**🎯 この機能により、AI生成されたコミットメッセージを既存のlazygitワークフローに干渉することなく、独立したウィンドウで快適に編集できるようになりました！**