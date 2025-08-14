#!/bin/bash
# Git分析機能のテストスクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../src"

# テスト結果カウンター
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# テスト関数
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -n "Testing: $test_name ... "
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local exit_status
    if (exit_status=$($test_function; echo $?)) && [[ $exit_status -eq 0 ]]; then
        echo "PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# アサーション関数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        if [[ -n "$message" ]]; then
            echo "Assertion failed: $message"
        fi
        echo "Expected: $expected"
        echo "Actual: $actual"
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local message="${3:-}"
    
    if echo "$text" | grep -F -q "$pattern"; then
        return 0
    else
        if [[ -n "$message" ]]; then
            echo "Assertion failed: $message"
        fi
        echo "Text does not contain pattern: $pattern"
        echo "Text: $text"
        return 1
    fi
}

# テスト用の一時Gitリポジトリを作成
setup_test_repo() {
    local test_repo_dir
    test_repo_dir=$(mktemp -d)
    
    # 現在のディレクトリを保存
    pushd "$test_repo_dir" >/dev/null
    
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    echo "$test_repo_dir"
}

# テスト用リポジトリをクリーンアップ
cleanup_test_repo() {
    local test_repo_dir="$1"
    if [[ -d "$test_repo_dir" ]]; then
        rm -rf "$test_repo_dir"
    fi
}

# テスト: ファイルタイプ識別
test_file_type_detection() {
    local test_repo
    test_repo=$(setup_test_repo)
    trap 'cleanup_test_repo "$test_repo"' RETURN
    
    # テストファイルを作成
    echo "console.log('hello');" > test.js
    echo "print('hello')" > test.py
    echo "#include <stdio.h>" > test.c
    echo "# README" > README.md
    
    git add .
    
    # Git analyzer を実行
    local result
    result=$(source "${SRC_DIR}/git_analyzer.sh" && analyze_files)
    
    # 結果をチェック
    assert_contains "$result" "javascript" "JavaScript ファイルが検出されない"
    assert_contains "$result" "python" "Python ファイルが検出されない"
    assert_contains "$result" "c++" "C ファイルが検出されない"
    assert_contains "$result" "markdown" "Markdown ファイルが検出されない"
    
    cleanup_test_repo "$test_repo"
}

# テスト: 変更統計
test_change_statistics() {
    local test_repo
    test_repo=$(setup_test_repo)
    trap 'cleanup_test_repo "$test_repo"' RETURN
    
    # 初期ファイルを作成してコミット
    echo "line 1" > test.txt
    git add test.txt
    git commit -m "initial commit" >/dev/null 2>&1
    
    # ファイルを変更
    echo -e "line 1\nline 2\nline 3" > test.txt
    git add test.txt
    
    # Git analyzer を実行
    local result
    result=$(source "${SRC_DIR}/git_analyzer.sh" && analyze_files)
    
    # JSON が有効かチェック
    if command -v jq >/dev/null 2>&1; then
        local total_files
        total_files=$(echo "$result" | jq -r '.summary.total_files')
        assert_equals "1" "$total_files" "ファイル数が正しくない"
        
        local total_additions
        total_additions=$(echo "$result" | jq -r '.summary.total_additions')
        assert_equals "2" "$total_additions" "追加行数が正しくない"
    fi
    
    cleanup_test_repo "$test_repo"
}

# テスト: 空のdiffエラーハンドリング
test_empty_diff_handling() {
    local test_repo
    test_repo=$(setup_test_repo)
    trap 'cleanup_test_repo "$test_repo"' RETURN
    
    # ファイルを作成するがステージしない
    echo "test content" > test.txt
    
    # ステージされたファイルチェック（失敗すべき）
    if source "${SRC_DIR}/git_analyzer.sh" && check_staged_files >/dev/null 2>&1; then
        cleanup_test_repo "$test_repo"
        return 1  # テスト失敗
    fi
    
    cleanup_test_repo "$test_repo"
    return 0  # テスト成功
}

# テスト: 複数ファイル変更
test_multiple_file_changes() {
    local test_repo
    test_repo=$(setup_test_repo)
    trap 'cleanup_test_repo "$test_repo"' RETURN
    
    # 複数ファイルを作成
    echo "function test() {}" > script.js
    echo "def test(): pass" > script.py
    echo "# Test" > README.md
    
    git add .
    
    # Git analyzer を実行
    local result
    result=$(source "${SRC_DIR}/git_analyzer.sh" && analyze_files)
    
    # JSON が有効かチェック
    if command -v jq >/dev/null 2>&1; then
        local total_files
        total_files=$(echo "$result" | jq -r '.summary.total_files')
        assert_equals "3" "$total_files" "複数ファイルが正しく検出されない"
        
        # ファイルパスの確認
        assert_contains "$result" "script.js" "JavaScript ファイルパスが含まれない"
        assert_contains "$result" "script.py" "Python ファイルパスが含まれない"
        assert_contains "$result" "README.md" "Markdown ファイルパスが含まれない"
    fi
    
    cleanup_test_repo "$test_repo"
}

# テスト: Git リポジトリではない場所での実行
test_non_git_repository() {
    local temp_dir="/tmp/non_git_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Git analyzer を実行（失敗すべき）
    if source "${SRC_DIR}/git_analyzer.sh" && main >/dev/null 2>&1; then
        cleanup_test_repo "$temp_dir"
        return 1  # テスト失敗
    fi
    
    cleanup_test_repo "$temp_dir"
    return 0  # テスト成功
}

# メイン関数
main() {
    echo "=== Git Analyzer テストスイート ==="
    echo
    
    # テストを実行
    run_test "ファイルタイプ識別" test_file_type_detection
    run_test "変更統計計算" test_change_statistics
    run_test "空のdiffエラーハンドリング" test_empty_diff_handling
    run_test "複数ファイル変更" test_multiple_file_changes
    run_test "非Gitリポジトリエラーハンドリング" test_non_git_repository
    
    echo
    echo "=== テスト結果 ==="
    echo "実行: $TESTS_RUN"
    echo "成功: $TESTS_PASSED"
    echo "失敗: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ すべてのテストが成功しました！"
        exit 0
    else
        echo "❌ $TESTS_FAILED 個のテストが失敗しました"
        exit 1
    fi
}

# スクリプトが直接実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi