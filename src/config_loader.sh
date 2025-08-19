#!/bin/bash
# 設定ファイル読み込みスクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
USER_CONFIG_DIR="${HOME}/.config/ai-commit-generator"

# YAMLをJSONに変換（yq v4必須）
yaml_to_json() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "{}"
        return 0
    fi
    
    # yq v4の確認
    if ! command -v yq >/dev/null 2>&1; then
        echo "❌ エラー: yqがインストールされていません" >&2
        echo "   インストール方法:" >&2
        echo "   brew install yq" >&2
        echo "   または: https://github.com/mikefarah/yq/#install" >&2
        return 1
    fi
    
    # yq v4を使用してJSONに変換
    if yq --version 2>/dev/null | grep -E -q "version v4|mikefarah"; then
        yq eval -o=json "$yaml_file" 2>/dev/null || echo "{}"
    else
        echo "❌ エラー: yq v4が必要です" >&2
        echo "   現在のバージョン: $(yq --version 2>/dev/null || echo '不明')" >&2
        echo "   必要なバージョン: yq v4.x (mikefarah/yq)" >&2
        echo "   インストール方法:" >&2
        echo "   brew install yq" >&2
        echo "   または: https://github.com/mikefarah/yq/#install" >&2
        return 1
    fi
}


# 簡単なYAML解析（フォールバック）
parse_simple_yaml() {
    local yaml_file="$1"
    
    # YAMLファイルから値を抽出
    local in_gemini=false
    local in_commit=false
    local in_ui=false
    local in_logging=false
    
    local model="gemini-pro"
    local temperature="0.3"
    local max_tokens="100"
    local timeout="30"
    local max_length="72"
    local use_conventional="true"
    local language="ja"
    local show_spinner="true"
    local spinner_style="dots"
    local confirmation="true"
    local level="info"
    local file=""
    
    # YAMLを行ごとに解析
    while IFS= read -r line; do
        # コメント行や空行をスキップ
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # セクション判定
        if [[ "$line" =~ ^gemini: ]]; then
            in_gemini=true; in_commit=false; in_ui=false; in_logging=false
        elif [[ "$line" =~ ^commit_message: ]]; then
            in_gemini=false; in_commit=true; in_ui=false; in_logging=false
        elif [[ "$line" =~ ^ui: ]]; then
            in_gemini=false; in_commit=false; in_ui=true; in_logging=false
        elif [[ "$line" =~ ^logging: ]]; then
            in_gemini=false; in_commit=false; in_ui=false; in_logging=true
        elif [[ "$line" =~ ^[a-zA-Z] ]]; then
            # 新しいトップレベルセクション
            in_gemini=false; in_commit=false; in_ui=false; in_logging=false
        fi
        
        # 値を抽出
        if [[ "$in_gemini" == true ]]; then
            [[ "$line" =~ model:[[:space:]]*(.+) ]] && model="${BASH_REMATCH[1]//\"/}"
            [[ "$line" =~ temperature:[[:space:]]*(.+) ]] && temperature="${BASH_REMATCH[1]}"
            [[ "$line" =~ max_tokens:[[:space:]]*(.+) ]] && max_tokens="${BASH_REMATCH[1]}"
            [[ "$line" =~ timeout:[[:space:]]*(.+) ]] && timeout="${BASH_REMATCH[1]}"
        elif [[ "$in_commit" == true ]]; then
            [[ "$line" =~ max_length:[[:space:]]*(.+) ]] && max_length="${BASH_REMATCH[1]}"
            [[ "$line" =~ use_conventional_commits:[[:space:]]*(.+) ]] && use_conventional="${BASH_REMATCH[1]}"
            [[ "$line" =~ language:[[:space:]]*([^#[:space:]]+) ]] && language="${BASH_REMATCH[1]//\"/}"
        elif [[ "$in_ui" == true ]]; then
            [[ "$line" =~ show_spinner:[[:space:]]*(.+) ]] && show_spinner="${BASH_REMATCH[1]}"
            [[ "$line" =~ spinner_style:[[:space:]]*(.+) ]] && spinner_style="${BASH_REMATCH[1]//\"/}"
            [[ "$line" =~ confirmation_required:[[:space:]]*(.+) ]] && confirmation="${BASH_REMATCH[1]}"
        elif [[ "$in_logging" == true ]]; then
            [[ "$line" =~ level:[[:space:]]*(.+) ]] && level="${BASH_REMATCH[1]//\"/}"
            [[ "$line" =~ file:[[:space:]]*(.+) ]] && file="${BASH_REMATCH[1]//\"/}"
        fi
    done < "$yaml_file"
    
    # JSONを出力
    cat <<EOF
{
  "gemini": {
    "model": "$model",
    "temperature": $temperature,
    "max_tokens": $max_tokens,
    "timeout": $timeout
  },
  "commit_message": {
    "max_length": $max_length,
    "use_conventional_commits": $use_conventional,
    "language": "$language"
  },
  "ui": {
    "show_spinner": $show_spinner,
    "spinner_style": "$spinner_style",
    "confirmation_required": $confirmation
  },
  "logging": {
    "level": "$level",
    "file": "$file"
  }
}
EOF
}

# デフォルト設定を読み込み
load_default_config() {
    local default_config="${CONFIG_DIR}/default.yml"
    yaml_to_json "$default_config"
}

# ユーザー設定を読み込み
load_user_config() {
    # ユーザー設定ファイルの候補
    local user_configs=(
        "${USER_CONFIG_DIR}/config.yml"
        "${USER_CONFIG_DIR}/config/default.yml"
        # 既存の設定ファイルも確認
        "${USER_CONFIG_DIR}/config/default.yml"
    )
    
    for config_file in "${user_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            yaml_to_json "$config_file"
            return 0
        fi
    done
    
    # 設定ファイルが見つからない場合は空のJSONを返す
    echo "{}"
}

# 設定をマージして読み込み
load_config() {
    local default_config
    local user_config
    default_config=$(load_default_config)
    user_config=$(load_user_config)
    
    # jqが利用可能な場合はマージ
    if command -v jq >/dev/null 2>&1; then
        # ユーザー設定が空でない場合のみマージ
        if [[ "$user_config" != "{}" ]] && [[ -n "$user_config" ]]; then
            echo "$default_config" | jq ". * $user_config" 2>/dev/null || echo "$default_config"
        else
            echo "$default_config"
        fi
    else
        # jqが無い場合はデフォルト設定のみ使用
        echo "$default_config"
    fi
}

# 設定値を取得
get_config_value() {
    local key="$1"
    local default_value="${2:-}"
    local config
    local value
    
    config=$(load_config)
    
    # jqが利用可能な場合
    if command -v jq >/dev/null 2>&1; then
        value=$(echo "$config" | jq -r "$key // empty" 2>/dev/null)
        
        if [[ -z "$value" ]] || [[ "$value" == "null" ]] || [[ "$value" == "empty" ]]; then
            echo "$default_value"
        else
            echo "$value"
        fi
    else
        # jqが利用できない場合はデフォルト値を返す
        echo "$default_value"
    fi
}

# ユーザー設定ディレクトリを作成
ensure_user_config_dir() {
    mkdir -p "$USER_CONFIG_DIR"
}

# サンプル設定ファイルを生成
generate_sample_config() {
    ensure_user_config_dir
    
    local sample_config="${USER_CONFIG_DIR}/config.yml.sample"
    
    cat > "$sample_config" <<'EOF'
# AI Commit Generator ユーザー設定
# ~/.config/ai-commit-generator/config.yml にコピーして使用してください

gemini:
  # Gemini APIモデル設定
  model: "gemini-pro"
  temperature: 0.3
  max_tokens: 100
  timeout: 30

commit_message:
  # コミットメッセージ設定
  max_length: 72
  use_conventional_commits: true
  language: "ja"  # ja または en

ui:
  # UI表示設定
  show_spinner: true
  spinner_style: "dots"
  confirmation_required: true

logging:
  # ログ設定
  level: "info"  # debug, info, warn, error
  file: ""  # 空の場合はコンソール出力のみ
EOF

    echo "サンプル設定ファイルが作成されました: $sample_config"
}

# 設定検証
validate_config() {
    local config
    config=$(load_config)
    
    # 設定が読み込めているかチェック
    if [[ -z "$config" ]] || [[ "$config" == "null" ]]; then
        echo "エラー: 設定ファイルを読み込めません" >&2
        return 1
    fi
    
    # jqが利用可能な場合のみ詳細検証
    if command -v jq >/dev/null 2>&1; then
        # 必須設定のチェック
        local model
        local language
        model=$(echo "$config" | jq -r '.gemini.model // null' 2>/dev/null)
        language=$(echo "$config" | jq -r '.commit_message.language // null' 2>/dev/null)
        
        if [[ -z "$model" ]] || [[ "$model" == "null" ]] || [[ "$model" == "empty" ]]; then
            echo "エラー: Geminiモデルが設定されていません" >&2
            return 1
        fi
        
        if [[ -n "$language" ]] && [[ "$language" != "ja" ]] && [[ "$language" != "en" ]]; then
            echo "警告: サポートされていない言語設定です: $language" >&2
        fi
    fi
    
    return 0
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]] && [[ $# -gt 0 ]]; then
    case "${1:-}" in
        "sample")
            generate_sample_config
            ;;
        "validate")
            validate_config
            ;;
        "show")
            config_output=$(load_config)
            if command -v jq >/dev/null 2>&1; then
                echo "$config_output" | jq .
            elif command -v python3 >/dev/null 2>&1; then
                echo "$config_output" | python3 -m json.tool 2>/dev/null || echo "$config_output"
            else
                echo "$config_output"
            fi
            ;;
        *)
            echo "使用方法: $0 [sample|validate|show]"
            echo "  sample   - サンプル設定ファイルを生成"
            echo "  validate - 設定ファイルを検証"
            echo "  show     - 現在の設定を表示"
            ;;
    esac
fi