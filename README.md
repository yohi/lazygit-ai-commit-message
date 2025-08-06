# Lazygit GeminiCLI Commit Plugin

LazygitでGeminiCLIを使用してAI駆動のコミットメッセージを生成するプラグインです。

## 概要

このプラグインは、Lazygitのカスタムコマンド機能を使用して、ステージングされたファイルの変更内容をGeminiCLIで分析し、適切なコミットメッセージを自動生成します。

### 主な機能

- 🤖 **AI駆動のコミットメッセージ生成**: GeminiCLIを使用してインテリジェントなコミットメッセージを生成
- 📝 **Conventional Commits対応**: Conventional Commits形式に従ったメッセージ生成
- 🔒 **セキュアな処理**: 機密情報の自動マスキング機能
- ⚙️ **高度にカスタマイズ可能**: YAML設定ファイルによる詳細な設定
- 🚀 **Lazygit統合**: シームレスなLazygitワークフロー統合
- 🌍 **多言語対応**: 日本語・英語等をサポート

## 依存関係

以下のツールが必要です：

- [Git](https://git-scm.com/) - バージョン管理システム
- [Lazygit](https://github.com/jesseduffield/lazygit) - Git TUI
- [GeminiCLI](https://github.com/google/gemini-cli) - Gemini API CLI
- [yq](https://github.com/mikefarah/yq) - YAML プロセッサ（v4以上必須）

### インストール方法

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install git
sudo snap install yq  # yq v4+
```

#### macOS (Homebrew):
```bash
brew install git yq  # Homebrewは自動的にv4+をインストール
```

**注意**: 古いyq v3がインストールされている場合は削除してv4をインストールしてください。

#### yq v3からv4へのアップグレード:
```bash
# Ubuntu/Debianの場合
sudo apt remove yq  # 古いバージョンを削除
sudo snap install yq

# macOSの場合
brew upgrade yq
```

#### GeminiCLI:
公式ドキュメントに従ってインストールしてください：
https://github.com/google/gemini-cli

## インストール

### 自動インストール

```bash
git clone https://github.com/yourname/lazygit-gemini-commit-plugin.git
cd lazygit-gemini-commit-plugin
./install.sh
```

### インストールオプション

```bash
./install.sh --check-only    # 依存関係チェックのみ
./install.sh --force         # 強制インストール（既存ファイル上書き）
```

## 使用方法

### 基本的な使い方

1. **Lazygitを起動**
   ```bash
   lazygit
   ```

2. **ファイルをステージング**
   - ファイルペインで変更したファイルを選択
   - スペースキーを押してステージング

3. **AIコミットメッセージ生成**
   - ファイルペインで `Ctrl+G` を押す
   - 確認ダイアログで `Enter` を押す

4. **メッセージを確認・編集**
   - 生成されたコミットメッセージが表示される
   - 必要に応じて編集してコミット

### キーバインディング

| キー | 機能 |
|------|------|
| `Ctrl+G` | AIコミットメッセージ生成 |
| `Enter` | 確認ダイアログで続行 |
| `Escape` | 確認ダイアログでキャンセル |

## 設定

### 設定ファイル

プラグインは以下の設定ファイルを使用します：

- **メイン設定**: `~/.config/lazygit/gemini-commit.yml`
- **Lazygit設定**: `~/.config/lazygit/config.yml`

### 設定例

```yaml
# ~/.config/lazygit/gemini-commit.yml
gemini:
  model: \"gemini-1.5-flash\"
  temperature: 0.3
  max_tokens: 200
  timeout: 30
  
commit:
  language: \"ja\"
  format: \"conventional\"
  max_diff_size: 10000
  
ui:
  show_progress: true
  confirm_before_commit: true
  editor_command: \"${EDITOR:-vim}\"
```

### 設定パラメータ

#### Gemini設定
- `model`: 使用するGeminiモデル（例: gemini-1.5-flash）
- `temperature`: 生成の創造性（0.0-2.0）
- `max_tokens`: 最大トークン数
- `timeout`: API呼び出しタイムアウト（秒）

#### コミット設定
- `language`: 生成言語（ja, en, zh, ko, es, fr, de）
- `format`: コミット形式（conventional, simple, free）
- `max_diff_size`: 最大差分サイズ（bytes）

#### UI設定
- `show_progress`: 進行状況表示の有無
- `confirm_before_commit`: コミット前確認の有無
- `editor_command`: 使用するエディタ

## コマンドラインオプション

プラグインは以下のコマンドラインオプションをサポート：

```bash
./gemini-commit.sh --help           # ヘルプ表示
./gemini-commit.sh --version        # バージョン表示
./gemini-commit.sh --config         # 現在の設定表示
./gemini-commit.sh --check-deps     # 依存関係チェック
./gemini-commit.sh --create-config  # デフォルト設定ファイル作成
```

## トラブルシューティング

### よくある問題

#### 1. 依存関係エラー
```
❌ エラー: 必要な依存関係が見つかりません: gemini-cli
```
**解決方法**: GeminiCLIをインストールしてください。

#### 2. APIキーエラー
```
❌ エラー: GeminiCLI APIへのアクセスに失敗しました
```
**解決方法**: Gemini API キーを正しく設定してください。

#### 3. ステージングファイルなし
```
❌ エラー: ステージングされたファイルがありません
```
**解決方法**: ファイルを先にステージングしてください。

### デバッグモード

問題が発生した場合は、デバッグモードで実行してください：

```bash
DEBUG=1 ./gemini-commit.sh
```

### ログ確認

- プラグインログ: stderr出力を確認
- Lazygitログ: `lazygit --debug` で起動

## アンインストール

```bash
./uninstall.sh                    # 通常のアンインストール
./uninstall.sh --keep-config      # 設定ファイル保持
./uninstall.sh --force            # 確認なしで実行
```

## 開発・貢献

### プロジェクト構造

```
lazygit-gemini-commit-plugin/
├── gemini-commit.sh           # メインスクリプト
├── lib/                       # ライブラリモジュール
│   ├── common.sh              # 共通関数
│   ├── config.sh              # 設定管理
│   ├── dependencies.sh        # 依存関係チェック
│   ├── git_operations.sh      # Git操作
│   ├── gemini_cli.sh          # GeminiCLI統合
│   └── commit_operations.sh   # コミット操作
├── config/                    # 設定ファイル
│   ├── gemini-commit.yml      # デフォルト設定
│   └── lazygit-config.yml     # Lazygit設定テンプレート
├── install.sh                 # インストールスクリプト
├── uninstall.sh               # アンインストールスクリプト
├── tests/                     # テストファイル
├── requirements.md            # 要件定義
├── design.md                  # 設計書
├── tasks.md                   # 実装計画
└── README.md                  # このファイル
```

### テスト

```bash
# 依存関係テスト
./gemini-commit.sh --check-deps

# 設定テスト
./gemini-commit.sh --config

# 機能テスト（要Git リポジトリ）
DEBUG=1 ./gemini-commit.sh
```

## ライセンス

[MIT License](LICENSE)

## 貢献

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'feat: 素晴らしい機能を追加'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 変更履歴

### v1.0.0 (2024-XX-XX)
- 初回リリース
- 基本的なAIコミットメッセージ生成機能
- Lazygit統合
- 設定ファイル対応
- インストール・アンインストール機能

## サポート

問題が発生した場合：

1. [Issues](https://github.com/yourname/lazygit-gemini-commit-plugin/issues)で既存の問題を確認
2. 新しいIssueを作成して問題を報告
3. デバッグ情報を含めて報告

## 関連プロジェクト

- [Lazygit](https://github.com/jesseduffield/lazygit) - Git TUI
- [GeminiCLI](https://github.com/google/gemini-cli) - Gemini API CLI
- [Conventional Commits](https://www.conventionalcommits.org/) - コミット規約