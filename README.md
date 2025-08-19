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

### Lazygit内でのキーバインド

| キー | 機能 | 環境 | 説明 |
|------|------|------|------|
| **Ctrl+G** | 🚀 新統合フロー | 全環境 | AI生成→自作ウィンドウ→コミット（**推奨**） |
| **Ctrl+A** | 自動コミット画面 | X11/tmux | AI生成後に自動的にコミット画面を表示 |
| **Alt+C** | 確認付き直接コミット | Wayland | AI生成→確認→直接コミット（Wayland対応） |
| **Ctrl+W** | カスタムTUIウィンドウ | 全環境 | AI生成→カスタムウィンドウで編集 |
| **Ctrl+S** | スマートモード | 全環境 | AI生成→自動ウィンドウ→コミット |
| **Alt+W** | 自動ウィンドウ起動 | 全環境 | AI生成→自動ウィンドウ起動（Lazygit統合） |
| **Ctrl+X** | 環境変数チェック | 全環境 | AI環境とツールの診断 |

### 🚀 新統合フロー（推奨）

**Ctrl+G** キーで利用できる新しい統合フローです：

1. Lazygitを起動
2. ファイルをステージ
3. `Ctrl+G` を押して統合フローを開始
4. **確認メッセージ** → `Enter` で続行
5. **AI分析・生成**: ステージされたファイルを自動分析してコミットメッセージを生成
6. **自作ウィンドウ**: 生成されたメッセージが事前入力された状態で専用編集ウィンドウが自動表示
7. **編集・確認**: 必要に応じてメッセージを編集、問題なければそのまま確認
8. **自動コミット**: ワンクリックでコミット完了

#### 統合フローの特徴
- ✅ **シームレス**: 全工程が一つのフローで完結
- ✅ **効率的**: 手動作業を最小限に削減
- ✅ **柔軟性**: 生成されたメッセージの編集が簡単
- ✅ **安全性**: 最終確認画面でメッセージを確認可能

### 🌟 その他の使用方法

#### Alt+C: 確認付き直接コミット（Wayland対応）
1. Lazygitを起動
2. ファイルをステージ
3. `Alt+C` を押してAI生成 + 確認付き直接コミット
4. 生成されたメッセージを確認
5. オプション選択:
   - `y`: そのままコミット
   - `e`: メッセージ編集
   - `p`: コミット+プッシュ
   - `n`: キャンセル

### コマンドライン使用

```bash
# 基本実行
ai-commit-generator

# 各種モード
ai-commit-generator --smart-mode        # スマートモード（推奨）
ai-commit-generator --custom-window     # カスタムTUIウィンドウ
ai-commit-generator --direct-commit     # 確認付き直接コミット
ai-commit-generator --generate-only     # AI生成のみ

# 診断・デバッグ
ai-commit-generator --diagnose          # システム診断
ai-commit-generator --check-env         # 環境変数チェック
ai-commit-generator --test-gemini       # Gemini CLI接続テスト
ai-commit-generator --dry-run          # ドライラン（実際の生成なし）
ai-commit-generator --log-level debug  # デバッグモード

# ヘルプ・情報
ai-commit-generator --help             # ヘルプ表示
ai-commit-generator --version          # バージョン情報
ai-commit-generator --generate-sample-config  # サンプル設定生成
```

### 🔧 高度な機能

#### カスタムウィンドウ機能
- **dialog/whiptail対応**: システムの利用可能エディターを自動検出
- **メッセージ事前入力**: AI生成メッセージが自動的に表示
- **リアルタイム編集**: ユーザーが自由にメッセージを編集可能
- **確認ダイアログ**: コミット前の最終確認

#### スマートモード
- **ワンクリック実行**: AI生成→編集→コミットを一連で自動実行
- **エラーリカバリ**: 各ステップでのエラーハンドリング
- **プログレス表示**: 処理状況のリアルタイム表示

#### 環境適応機能
- **自動環境検出**: X11/Wayland/tmux環境を自動識別
- **フォールバック機能**: エディターが利用できない環境での代替手段
- **権限管理**: 必要な権限やグループの自動設定提案

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

### ウィンドウ表示問題

#### 症状
生成AI処理完了後、ウィンドウが自動で開かない

#### 解決策
1. **TTY環境の確認**: `tty`コマンドで端末が利用可能か確認
2. **対話モード強制**: `--force-interactive`オプションを使用
3. **エディター確認**: `dialog`, `whiptail`, `nano`のインストール状況確認
4. **ログ確認**: `/tmp/ai-commit-generator.log`でエラー詳細を確認

### 環境別の問題

#### Wayland環境
- **対応キー**: `Alt+C` (確認付き直接コミット)
- **ツール**: `ydotool`の自動インストール・設定
- **権限**: ユーザーの`input`グループ追加が必要

#### X11/tmux環境  
- **対応キー**: `Ctrl+A` (自動コミット画面)
- **ツール**: `xdotool`の利用
- **環境変数**: `DISPLAY`の正しい設定

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
