# 🚀 新統合フロー使用ガイド

AI Commit Generatorの新しい統合フロー（Ctrl+G）の詳細使用ガイドです。

## 📋 概要

新統合フローは、ファイルのステージングからコミット完了まで、すべての工程を一つのシームレスなフローで実行できる機能です。

## 🎯 フロー詳細

### 1. 事前準備
```bash
# Lazygitを起動
lazygit

# または手動でファイルをステージ
git add <ファイル名>
```

### 2. 統合フロー実行

#### Lazygit内での操作
1. ファイルを選択してステージ（`<space>`キー）
2. `Ctrl+G` を押下
3. 確認ダイアログで `Enter` を押下

#### 自動実行される処理
1. **ファイル分析**: ステージされたファイルの変更内容を自動分析
2. **AI生成**: Gemini APIを使用してコミットメッセージを生成
3. **自作ウィンドウ表示**: 生成されたメッセージが事前入力された状態で専用編集ウィンドウが自動表示

### 3. 自作ウィンドウでの編集・確認

#### ウィンドウ表示内容
```
🤖 AI生成コミットメッセージ:
==================================
feat: 新機能を追加
==================================

📝 選択してください:
1) このメッセージをそのまま使用
2) メッセージを編集
3) キャンセル

選択 (1-3): 
```

#### 選択肢の説明
- **1**: AI生成メッセージをそのまま使用してコミット
- **2**: 新しいメッセージを入力して編集
- **3**: 操作をキャンセル

#### 環境対応
- **Lazygitモード**: 専用の対話エディターを使用
- **通常モード**: dialog/whiptail/nano等の高機能エディターを使用
- **非対話環境**: 自動的にAI生成メッセージを使用

### 4. 自動コミット
- 編集完了後、自動的にコミットが実行されます
- 最終的なコミットメッセージが表示されます
- 成功時: `🎉 コミット完了！`

## ⚙️ 技術的詳細

### 実装されたフロー
```
ステージング → 確認 → AI分析 → メッセージ生成 → 自作ウィンドウ → 編集 → コミット
```

### 主要な改善点
1. **統合性**: 全工程が一つのコマンドで完結
2. **効率性**: 手動操作を最小限に削減
3. **柔軟性**: 各段階でのカスタマイズが可能
4. **安全性**: 最終確認とエラーハンドリング

### 設定ファイル
```yaml
# ~/.config/ai-commit-generator/config/default.yml
gemini:
  model: "gemini-2.5-flash"
  temperature: 0.3
  max_tokens: 100

commit_message:
  max_length: 72
  language: "ja"
  use_conventional_commits: true
```

## 🔧 カスタマイズ

### Lazygit設定
```yaml
# ~/.config/lazygit/config.yml に自動追加される
customCommands:
  - key: "<c-g>"
    context: "files"
    command: "ai-commit-generator --lazygit-mode"
    description: "🚀 AI生成→自作ウィンドウ→コミット（統合フロー）"
```

### コマンドラインからの実行
```bash
# 統合フローを直接実行
ai-commit-generator --lazygit-mode

# 生成のみ（テスト用）
ai-commit-generator --generate-only

# カスタムウィンドウのみ
ai-commit-generator --custom-window
```

## 🐛 トラブルシューティング

### よくある問題

#### 1. ウィンドウが表示されない
```bash
# 依存関係確認
which dialog || which whiptail || which nano

# 手動インストール
sudo apt install dialog whiptail nano
```

#### 2. AI生成に失敗
```bash
# API キー確認
echo $GEMINI_API_KEY

# 診断実行
ai-commit-generator --diagnose
```

#### 3. ステージファイルなしエラー
```bash
# ファイルをステージしてから実行
git add <ファイル名>
```

### ログ確認
```bash
# 詳細ログ
export LOG_LEVEL=debug
ai-commit-generator --lazygit-mode

# ログファイル確認
tail -f /tmp/ai-commit-generator.log
```

## 🚀 パフォーマンス

### 実行時間目安
- **ファイル分析**: 〜1秒
- **AI生成**: 2-5秒（ネットワーク依存）
- **ウィンドウ表示**: 即座
- **コミット実行**: 〜1秒

### 最適化のヒント
1. **ステージファイル数**: 10ファイル以下が推奨
2. **メッセージ長**: 50文字以内が最適
3. **ネットワーク**: 安定したインターネット接続

## 📚 参考資料

- [メインREADME](./README.md)
- [Lazygit設定ガイド](./LAZYGIT_SETUP.md)
- [システム診断](./ai-commit-generator --diagnose)

## 💡 今後の予定

- [ ] ウィンドウのさらなるカスタマイズ対応
- [ ] 複数言語対応の拡張
- [ ] プリセットメッセージ機能
- [ ] Git hooks統合

---

**🎉 新統合フローで効率的なコミットライフを！**