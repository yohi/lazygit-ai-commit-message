次のAIエージェント用レビュー指摘プロンプトをひとつずつ対応してください。
ただし、指摘が正しいとは限らないので規約や環境、構造などを考慮し指摘されたことをしっかり精査した上で対応可否の判断を下すこと。
最後に対応不要と判断したプロンプトに関してはその書き出しと、対応不要と判断した理由を下記のように出力してください。
例）
```
1. In backend-auth/server.js around line 44,
    - 開発・ローカル環境ではMemoryStoreで十分。本番環境では別途Redis/MongoDBを使用するべきですが、この段階では不要。

2. In backend-auth/server.js around lines 127 to 163,
    - シンプルな開発用認証サーバーでは、HTMLのインライン埋め込みは許容範囲。テンプレートエンジンの導入は複雑性を増すだけ。

...
```

対応が全て終わったらGitにコミット・プッシュを行ってください。

# Prompt For AI Agents List

- In tests/test_git_analyzer.sh around lines 22 to 29, run each test function inside a subshell to isolate side effects (cwd, trap) but keep result handling in the parent: invoke the test in a subshell, capture its exit status, then in the parent echo "PASS"/"FAIL" and increment TESTS_PASSED or TESTS_FAILED based on that captured status; this preserves isolation while ensuring counters are updated in the parent shell.

- In tests/test_git_analyzer.sh around lines 54 to 64, the assert_contains function uses grep which treats the pattern as a regular expression and can misdetect when pattern contains regex metacharacters (filenames or JSON fragments); change the grep invocation to use fixed-string mode (e.g., grep -F -q) and keep proper quoting of the pattern variable so the pattern is matched literally, ensuring the function returns 0 on match and 1 on failure as before.

- In src/gemini_client.sh around lines 339 to 346, split the declaration and assignment for prompt and quote command substitutions: declare local prompt on its own line (e.g., local prompt) and then assign prompt="$(generate_prompt "$diff_content" "$file_analysis" "$language")" so any evaluation errors surface; similarly, in the conditional use quoted command substitution for the response to avoid word-splitting and preserve whitespace: if ! response="$(call_gemini_cli "$prompt" "$model" "$temperature" "$max_tokens" "$timeout")"; then return 1; fi.

- In src/gemini_client.sh around lines 26 to 34 (and likewise at lines 117-118), the script directly references the literal "gemini" binary; replace those direct references with a single call to get_gemini_command to centralize binary resolution and logging. Modify the existence check to use the value returned by get_gemini_command, and change error/log messages to reference that variable (or the function result) instead of the hardcoded string, ensuring any future binary substitution is honored and logging is consistent.

- src/gemini_client.sh around lines 94-99 (also apply same changes at 146-148, 191-200, 213-219): remove any rm -f of temp_output/error_file from handle_gemini_error so it no longer attempts to clean files out of its caller's scope, change handle_gemini_error to return only an exit code (e.g. 0 for "partial success" or non-zero for failure) and not echo the result when returning 0, and update call_gemini_cli so it performs all temp file cleanup itself before any early return; additionally, when handle_gemini_error returns 0, have call_gemini_cli avoid re-echoing the same $result to prevent double output and ensure rm -f "$temp_output" "$error_file" runs on every return path.

- In src/gemini_client.sh around lines 192, 211 and 259, the code initializes local variables with command substitution which ShellCheck flags (SC2155); split each into two statements: first declare the local variable (e.g., local error_output="") and then assign using the command substitution on the next line (error_output=$(cat "$error_file" 2>/dev/null || echo "")), and after the assignment check the command's exit status or handle failures explicitly so errors are surfaced instead of being masked by combined declaration+assignment.

- In src/gemini_client.sh around lines 284 to 293, the current pattern assigns response via command substitution and then checks $? which is brittle under set -e; change it to use a negated if with a quoted command substitution so failures are detected immediately (i.e., assign to the local response inside an if ! ...; then return 1 on failure), ensuring the command substitution is quoted and the local response variable is declared before the if.

- In src/ui_helper.sh around lines 12 and also lines 31-33, the spinner frames are defined as a single UTF-8 string which gets sliced by byte-indexing and corrupts multibyte characters; replace that string with an array of frames (e.g. frames=( "⠋" "⠙" ... )) and update spinner logic to index into the array instead of using substring slicing; additionally detect UTF-8 support (e.g. check LC_CTYPE or LANG) and fall back to an ASCII frame array if UTF-8 is not supported so non-UTF8 environments display correctly.

- In src/ui_helper.sh around lines 117-125 (and likewise update 134-138), guard against unset/non-numeric/negative total and ensure UI prints go to stderr: validate that $total is set and is a non-negative integer (e.g. using a regex or arithmetic check), print an error to stderr and return non-zero when invalid, treat total==0 as a special case to avoid division by zero, and ensure subsequent arithmetic uses a safe numeric value; also change progress/UI echo calls to write to stderr to avoid mixing with stdout.

- In src/ui_helper.sh around lines 168 to 186, the current run_with_spinner uses command substitution which strips trailing newlines and can OOM on large output; change it to create a temporary file (mktemp), redirect the command's stdout/stderr into that file while capturing its exit code, then stop the spinner and on success print the success message and cat the temp file (preserving newlines), on failure call show_error and include the file contents (or a reasonable head/tail if huge), ensure you remove the temp file and use trap to clean it up on exit or interrupt.

- In src/git_analyzer.sh around lines 60 to 69, the extension-to-file_type mapping in the case "${filename##*.}" lacks C/C++ branches so .c/.cpp files fall back to "text"; add branches so ".c)" sets file_type="c" and ".cpp|cc|cxx)" sets file_type="c++", and then run tests and update tests/test_git_analyzer.sh around lines 109 to 113 to match the expected values (e.g., assert_contains "$result" "c" for .c files or "c++" for .cpp files) so implementation and tests are consistent.

- In tests/test_git_analyzer.sh around lines 203 to 215, the test creates a temp dir with a fixed /tmp path and uses cd which can break CWD and cleanup on failures; replace that block to create an isolated temp dir with mktemp -d, use pushd to change into it and popd to restore the original directory, and add a trap on RETURN (or EXIT) to call cleanup_test_repo and remove the temp dir so cleanup runs even on early returns or failures; ensure the test still asserts that running the analyzer in a non-git repo fails and that the trap/popd restore the original CWD and remove the temp directory.