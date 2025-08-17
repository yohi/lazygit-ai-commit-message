# 🚀 AI Commit Generator - 自動ウィンドウ起動機能ガイド

## 📋 概要

AI Commit Generatorの自動ウィンドウ起動機能は、AI生成完了後に自動的にカスタムコミットウィンドウを表示する機能です。これにより、シームレスな「AI生成→編集→コミット」ワークフローが実現されます。

### 🎯 新機能の特徴

- **自動ウィンドウ起動**: AI生成完了後に自動でカスタムTUIウィンドウを表示
- **スマートモード**: AI生成→自動ウィンドウ→コミットを一連で実行
- **Lazygit統合**: Lazygit内からスムーズに自動ウィンドウを起動
- **フォールバック機能**: エディターが利用できない環境でも動作
- **エラーハンドリング**: 堅牢なエラー処理とユーザーガイダンス

## 🚀 利用可能なモード

### 1. **スマートモード** 🌟 （推奨）

**最も便利な統合モード**

```bash
# コマンドライン
ai-commit-generator --smart-mode

# Lazygit内
Ctrl+S
```

**フロー:**
```
ファイルステージ → AI生成 → 自動ウィンドウ表示 → ユーザー編集 → コミット実行
```

**特徴:**
- ワンストップでコミット完了
- 進行状況を表示
- エラー時の適切なガイダンス

### 2. **自動ウィンドウモード**

**ウィンドウ自動起動に特化**

```bash
# コマンドライン  
ai-commit-generator --auto-window

# Lazygit内
Ctrl+W
```

**フロー:**
```
AI生成 → 自動ウィンドウ表示 → ユーザー編集 → 確認 → コミット実行
```

### 3. **Lazygit統合自動ウィンドウ**

**Lazygitワークフローとの統合**

```bash
# Lazygit内
Alt+W
```

**フロー:**
```
AI生成 → Lazygitログ表示 → 別プロセスで自動ウィンドウ起動
```

**特徴:**
- Lazygitの処理を妨げない
- バックグラウンドでウィンドウ起動
- 非同期処理

## 🔧 設定方法

### Lazygit設定の更新

`~/.config/lazygit/config.yml` に以下を追加:

```yaml
customCommands:
  # スマートモード（推奨）
  - key: "<c-s>"
    context: "files"
    command: "ai-commit-generator --smart-mode"
    description: "🚀 スマートモード（AI生成→自動ウィンドウ→コミット）"
    output: "logWithPty"
    stream: false
    prompts:
      - type: "confirm"
        title: "🚀 スマートモード"
        body: "AI生成→カスタムウィンドウで編集→コミットを自動実行します。続行しますか？"

  # カスタムウィンドウ（既存）
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

  # Lazygit統合自動ウィンドウ
  - key: "<a-w>"
    context: "files"
    command: "ai-commit-generator --auto-window --lazygit-mode"
    description: "AI生成→自動ウィンドウ起動（Lazygit統合）"
    output: "logWithPty"
    stream: false
    prompts:
      - type: "confirm"
        title: "AI生成 + 自動ウィンドウ"
        body: "AI生成完了後に自動でカスタムウィンドウを起動します。続行しますか？"
```

## 🖥️ ウィンドウの操作

### 利用可能なエディター（優先順位順）

1. **dialog** - 高機能なTUIダイアログ
2. **whiptail** - 軽量なTUIダイアログ
3. **nano/vi** - テキストエディター
4. **フォールバック** - シンプル選択・入力モード

### フォールバック機能

エディターが利用できない環境では、以下の選択肢が表示されます：

```
選択してください:
1) このメッセージをそのまま使用
2) 新しいメッセージを入力
3) キャンセル
```

## 🔄 ワークフロー比較

| モード | キー | AI生成 | ウィンドウ | コミット | 用途 |
|--------|------|--------|-----------|----------|------|
| **従来のLazygit** | `Ctrl+G` | ✅ | ❌ | ❌ | 確認のみ |
| **自動コミット** | `Ctrl+A` | ✅ | 既存UI | ✅ | 標準利用 |
| **直接コミット** | `Alt+C` | ✅ | ❌ | ✅ | 高速処理 |
| **カスタムウィンドウ** | `Ctrl+W` | ✅ | ✅ | 手動 | 詳細編集 |
| **🌟 スマートモード** | `Ctrl+S` | ✅ | ✅ | ✅ | **推奨** |
| **自動ウィンドウ** | `Alt+W` | ✅ | ✅ | ✅ | Lazygit統合 |

## 📝 使用例

### 1. 日常的な開発作業（推奨）

```bash
# ファイルを編集
echo "新機能を追加" >> feature.js

# ステージング
git add feature.js

# Lazygitでスマートモード実行
# Ctrl+S → 確認 → AI生成 → ウィンドウ編集 → コミット完了
```

### 2. 詳細なコミットメッセージが必要な場合

```bash
# 複数ファイルを変更
git add .

# Lazygitでカスタムウィンドウモード
# Ctrl+W → AI生成 → 詳細編集 → 手動コミット
```

### 3. スクリプトでの自動化

```bash
#!/bin/bash
# 自動コミットスクリプト

git add .

# AI生成→自動ウィンドウ→コミットを一括実行
ai-commit-generator --smart-mode
```

### 4. CI/CDパイプラインでの利用

```bash
# プリコミットフックでの自動メッセージ生成
if [[ -n "$(git diff --cached)" ]]; then
    # 生成のみ（ウィンドウなし）
    suggested_message=$(ai-commit-generator --generate-only)
    echo "Suggested: $suggested_message"
fi
```

## 🧪 テスト

### 基本テスト

```bash
# 全機能テスト
./scripts/test_auto_window.sh --all

# 個別テスト
./scripts/test_auto_window.sh --smart-mode
./scripts/test_auto_window.sh --auto-window
./scripts/test_auto_window.sh --fallback
```

### 手動テスト

```bash
# 1. テスト環境準備
echo "test" > test.txt && git add test.txt

# 2. スマートモードテスト
ai-commit-generator --smart-mode

# 3. 自動ウィンドウモードテスト  
ai-commit-generator --auto-window

# 4. クリーンアップ
rm test.txt && git reset HEAD test.txt
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. ウィンドウが表示されない

**原因**: エディターが見つからない

**解決方法**:
```bash
# エディターのインストール
sudo apt install dialog whiptail nano  # Ubuntu/Debian
brew install dialog                     # macOS
```

#### 2. 自動起動が機能しない

**原因**: プロセス間通信エラー

**解決方法**:
```bash
# ログ確認
tail -f /tmp/ai-commit-generator.log

# 手動プロセス確認
ps aux | grep ai-commit-generator
```

#### 3. コミットに失敗する

**原因**: ステージされたファイルがない

**解決方法**:
```bash
# ステージ状況確認
git status

# ファイルをステージ
git add .
```

### デバッグモード

```bash
# 詳細ログ出力
ai-commit-generator --smart-mode --log-level debug

# ログファイル確認
tail -f /tmp/ai-commit-generator.log
```

## 🚦 エラーハンドリング

### 自動復旧機能

- **エディター選択**: 利用可能なエディターを自動選択
- **フォールバック**: シンプル入力モードへ自動切り替え
- **メッセージ保持**: 編集中にエラーが発生してもメッセージを保持
- **プロセス監視**: 自動起動プロセスの状態監視

### エラー時のガイダンス

エラー発生時に表示される情報:
- 具体的なエラー内容
- 推奨される解決方法  
- 代替手段の提案
- ログファイルの場所

## 🔮 今後の拡張予定

- **履歴機能**: 過去のAI生成メッセージ履歴
- **テンプレート**: カスタムコミットメッセージテンプレート
- **プラグイン**: サードパーティエディター対応
- **設定UI**: グラフィカルな設定インターフェース
- **統計情報**: AI生成・コミット統計の表示

## 📊 パフォーマンス

### 実行時間の目安

| 操作 | 時間 | 備考 |
|------|------|------|
| AI生成 | 2-5秒 | Gemini APIの応答時間に依存 |
| ウィンドウ起動 | <1秒 | ローカル処理 |
| コミット実行 | <1秒 | Git処理時間 |
| **総計（スマートモード）** | **3-7秒** | **エンドツーエンド** |

### リソース使用量

- **メモリ**: 10-20MB（bashプロセス）
- **CPU**: 軽微（ダイアログ表示時のみ）
- **ディスク**: 一時ファイル数KB

---

**🎯 この自動ウィンドウ機能により、AI生成からコミット完了までが完全に自動化され、開発者の生産性が大幅に向上します！**

**推奨**: まずは `Ctrl+S` のスマートモードから始めて、ワークフローに慣れてから他のモードを試してください。