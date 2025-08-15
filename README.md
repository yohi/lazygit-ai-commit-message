# AI Commit Generator

LazygitのためのAI駆動コミットメッセージ生成プラグインです。Gemini CLIを使用して、ステージされたファイルの変更内容を分析し、適切なコミットメッセージを自動生成します。

## 機能

- 🤖 **AI駆動**: Gemini APIを使用した高品質なコミットメッセージ生成
- 🎯 **Lazygit統合**: シームレスなLazygitワークフロー統合
- 📊 **インテリジェント分析**: Git diffとファイルタイプの詳細分析
- 🌐 **多言語対応**: 日本語・英語のコミットメッセージ生成
- ⚙️ **カスタマイズ可能**: 豊富な設定オプション
- 🛡️ **堅牢なエラーハンドリング**: 包括的なエラー処理とユーザーフレンドリーなメッセージ

## 前提条件

### 必須
- **Git**: バージョン管理システム
- **Bash**: シェル環境
- **Lazygit**: Git TUIツール

### 推奨
- **jq**: JSON処理ツール
- **yq**: YAML処理ツール
- **Gemini CLI**: Google Gemini API クライアント

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/your-repo/ai-commit-generator.git
cd ai-commit-generator
```

### 2. インストールスクリプトを実行

```bash
./scripts/install.sh
```

### 3. Gemini CLIをインストール

```bash
# Node.js版
npm install -g @google/generative-ai-cli

# または Python版
pip install google-generativeai-cli
```

### 4. Gemini APIキーを設定

```bash
export GEMINI_API_KEY="your-api-key"
```

APIキーの取得: [Google AI Studio](https://makersuite.google.com/app/apikey)

## 使用方法

### 基本的な使用方法

1. Lazygitを起動
2. ファイルをステージ
3. `Ctrl+G` を押してAIコミットメッセージ生成を開始
4. 生成されたメッセージを確認・編集
5. コミット実行

### コマンドライン使用

```bash
# 基本実行
ai-commit-generator

# システム診断
ai-commit-generator --diagnose

# ドライラン（実際の生成なし）
ai-commit-generator --dry-run

# デバッグモード
ai-commit-generator --log-level debug

# ヘルプ表示
ai-commit-generator --help
```

## 設定

### ユーザー設定ファイル

`~/.config/ai-commit-generator/config.yml`

```yaml
gemini:
  model: "gemini-pro"
  temperature: 0.3
  max_tokens: 100
  timeout: 30

commit_message:
  max_length: 72
  use_conventional_commits: true
  language: "ja"  # ja または en

ui:
  show_spinner: true
  spinner_style: "dots"
  confirmation_required: true

logging:
  level: "info"  # debug, info, warn, error
  file: ""  # 空の場合はコンソール出力のみ
```

### サンプル設定生成

```bash
ai-commit-generator --generate-sample-config
```

### Lazygit設定

`~/.config/lazygit/config.yml`にカスタムコマンドが自動追加されます：

```yaml
customCommands:
  - key: '<c-g>'
    context: 'files'
    command: 'ai-commit-generator'
    description: 'AIコミットメッセージ生成'
    subprocess: true
```

## エラーハンドリング

### よくあるエラーと解決方法

#### Gemini CLI未インストール
```
❌ Gemini CLIがインストールされていません

解決方法:
  npm install -g @google/generative-ai-cli
```

#### APIキー未設定
```
❌ Gemini API呼び出しエラー

解決方法:
  export GEMINI_API_KEY="your-api-key"
```

#### ステージファイルなし
```
❌ ステージされたファイルがありません

解決方法:
  git add <ファイル名>
```

### システム診断

```bash
ai-commit-generator --diagnose
```

## アーキテクチャ

```
ai-commit-generator/
├── ai-commit-generator     # メインスクリプト
├── src/                   # ソースコード
│   ├── git_analyzer.sh    # Git diff分析
│   ├── gemini_client.sh   # Gemini CLI統合
│   ├── config_loader.sh   # 設定管理
│   ├── error_handler.sh   # エラーハンドリング
│   ├── ui_helper.sh       # UI表示
│   └── logger.sh          # ログ機能
├── config/                # 設定ファイル
│   ├── default.yml        # デフォルト設定
│   └── lazygit.yml       # Lazygit統合設定
└── scripts/               # インストールスクリプト
    └── install.sh
```

## 開発

### テスト実行

```bash
# Git分析テスト
./src/git_analyzer.sh

# Gemini CLIテスト
./src/gemini_client.sh "test diff" "{}"

# エラーハンドリングテスト
./src/error_handler.sh test-error

# UI表示テスト
./src/ui_helper.sh spinner
```

### 設定検証

```bash
./src/config_loader.sh validate
```

### ログ設定

デバッグログを有効にする：

```bash
export LOG_LEVEL=debug
ai-commit-generator
```

## アンインストール

```bash
./scripts/install.sh --uninstall
```

## トラブルシューティング

### パフォーマンス問題

- **大きなdiff**: `max_tokens`設定を調整
- **タイムアウト**: `timeout`設定を増加
- **レート制限**: 使用頻度を調整

### 設定問題

- **設定ファイル破損**: サンプル設定を再生成
- **Lazygit統合失敗**: 手動で設定ファイルを確認

### ネットワーク問題

- **プロキシ環境**: 環境変数でプロキシ設定
- **ファイアウォール**: `ai.google.dev`へのアクセス許可

## 貢献

1. フォークを作成
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) ファイルを参照

## 謝辞

- [Lazygit](https://github.com/jesseduffield/lazygit) - 素晴らしいGit TUIツール
- [Google Gemini](https://ai.google.dev/) - 強力なAI API
- コミュニティの皆様のフィードバックと貢献

## サポート

- 📚 [Wiki](https://github.com/your-repo/ai-commit-generator/wiki)
- 🐛 [Issues](https://github.com/your-repo/ai-commit-generator/issues)
- 💬 [Discussions](https://github.com/your-repo/ai-commit-generator/discussions)