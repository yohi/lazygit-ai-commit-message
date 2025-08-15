# 🚀 AI生成 + 自動コミット統合ガイド

## 🎯 概要

AI Commit GeneratorがLazygitと完全統合され、**AI生成から自動コミットまでワンステップ**で実行できるようになりました。

## ✨ 新機能: 自動コミット統合

### 🔑 キーバインド

| キー | 機能 | 動作 |
|------|------|------|
| **Ctrl+A** | AI生成 + 自動コミット | **推奨**：ワンステップでAI生成〜コミット完了 |
| Ctrl+G | AI生成のみ | 従来方式：生成後に手動で「c」キー |
| Ctrl+X | 環境チェック | AI環境の診断 |

## 🎯 推奨ワークフロー（Ctrl+A）

### 1️⃣ ファイルをステージ
```
- ファイル一覧でSpaceキーでステージ
- または「a」キーで全ファイルをステージ
```

### 2️⃣ Ctrl+A を押す
```
✅ 確認ダイアログが表示
「AIがメッセージを生成し、自動でコミットエディタを開きます。続行しますか？」
```

### 3️⃣ AI生成プロセス（自動）
```
🤖 AIコミットメッセージを生成中...

📊 ステージされたファイルを分析中...
✅ ファイル分析完了

🧠 Gemini AIでコミットメッセージを生成中...
✅ コミットメッセージ生成完了

📝 生成されたコミットメッセージ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
feat: 新機能の実装
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 4️⃣ コミットエディタ自動起動
```
🎯 コミットエディタを起動中...
   （メッセージを確認・編集してコミットを完了してください）

[エディタが自動で開き、AI生成メッセージが事前入力済み]
```

### 5️⃣ メッセージ確認・編集
```
- 生成されたメッセージを確認
- 必要に応じて編集
- 保存してコミット完了 または ESCでキャンセル
```

### 6️⃣ 完了
```
🎉 コミット完了！
✅ AIが生成したメッセージでコミットされました
```

## 💡 従来方式との比較

### 🆚 方式比較

| 項目 | Ctrl+G（従来） | **Ctrl+A（新機能）** |
|------|----------------|---------------------|
| ステップ数 | 3ステップ | **1ステップ** |
| 操作 | AI生成 → 手動「c」→ コミット | **AI生成 → 自動コミット** |
| メッセージ編集 | ⭐ 可能 | **⭐ 可能** |
| キャンセル | ⭐ 可能 | **⭐ 可能** |
| 推奨度 | 🔶 標準 | **🌟 推奨** |

### 🔄 操作フロー比較

#### Ctrl+G（従来方式）
```
1. Ctrl+G → AI生成
2. 手動で「c」キー → コミット画面
3. メッセージ確認・編集
```

#### Ctrl+A（新方式）✨
```
1. Ctrl+A → AI生成 + 自動コミット画面
2. メッセージ確認・編集
```

## 🎨 カスタマイズオプション

### 💾 メッセージのテンプレート保存
従来の方式（Ctrl+G）も利用可能で、以下の追加機能があります：

```bash
# テンプレート関連コマンドを追加（オプション）
./add_template_commands.sh
```

追加されるキーバインド：
- **Ctrl+T**: AIテンプレートをクリア

## 🔧 技術的詳細

### 🏗️ 実装方式

1. **commit-modeオプション**: `--commit-mode`フラグで自動コミットモードを有効化
2. **一時ファイル**: 生成メッセージを`/tmp/ai-commit-message.txt`に保存
3. **Git統合**: `git commit --edit --file`でエディタ起動
4. **エラーハンドリング**: コミットキャンセル時の適切な処理

### 📁 関連ファイル

```
ai-commit-generator/
├── ai-commit-generator           # メインスクリプト（--commit-mode追加）
├── add_commit_mode.sh           # Lazygit設定追加スクリプト
├── clear_template.sh            # テンプレートクリア用
└── COMMIT_INTEGRATION_GUIDE.md  # このガイド
```

### ⚙️ 設定内容

```yaml
customCommands:
  - key: '<c-a>'
    context: 'files'
    command: 'ai-commit-generator --commit-mode'
    description: 'AI生成 + 自動コミット'
    loadingText: 'AIコミットメッセージ生成中...'
    output: 'terminal'  # コミットエディタ起動のため
    prompts:
      - type: 'confirm'
        title: 'AI生成 + 自動コミット'
        body: 'AIがメッセージを生成し、自動でコミットエディタを開きます。続行しますか？'
```

## 🐛 トラブルシューティング

### よくある問題

1. **コミットエディタが開かない**
   ```bash
   # Gitエディタ設定を確認
   git config --get core.editor
   
   # 設定されていない場合
   git config --global core.editor "code --wait"  # VS Code
   git config --global core.editor "vim"          # Vim
   ```

2. **権限エラー**
   ```bash
   # スクリプトに実行権限を付与
   chmod +x ai-commit-generator
   ```

3. **パスの問題**
   ```bash
   # ai-commit-generatorがパスにあるか確認
   which ai-commit-generator
   
   # 設定で絶対パスを使用
   command: '/full/path/to/ai-commit-generator --commit-mode'
   ```

### デバッグ

```bash
# コマンドライン直接実行でテスト
./ai-commit-generator --commit-mode

# ログ確認
tail -f /tmp/ai-commit-generator.log

# 詳細デバッグ
./ai-commit-generator --commit-mode --log-level debug
```

## 🎉 まとめ

- **Ctrl+A**: AI生成 + 自動コミット（**推奨**）
- **Ctrl+G**: AI生成のみ（従来方式）
- **Ctrl+X**: 環境チェック

新しい **Ctrl+A** を使用することで、Lazygit内で**ワンステップ**でAI生成からコミット完了まで実行できます！

---

**Happy Coding with AI! 🤖✨**