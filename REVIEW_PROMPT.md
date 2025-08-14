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

- In tests/test_git_analyzer.sh around lines 54 to 64, the assert_contains function uses grep which treats the pattern as a regular expression and can misdetect when pattern contains regex metacharacters (filenames or JSON fragments); change the grep invocation to use fixed-string mode (e.g., grep -F -q) and keep proper quoting of the pattern variable so the pattern is matched literally, ensuring the function returns 0 on match and 1 on failure as before.

- src/gemini_client.sh around lines 94-99 (also apply same changes at 146-148, 191-200, 213-219): remove any rm -f of temp_output/error_file from handle_gemini_error so it no longer attempts to clean files out of its caller's scope, change handle_gemini_error to return only an exit code (e.g. 0 for "partial success" or non-zero for failure) and not echo the result when returning 0, and update call_gemini_cli so it performs all temp file cleanup itself before any early return; additionally, when handle_gemini_error returns 0, have call_gemini_cli avoid re-echoing the same $result to prevent double output and ensure rm -f "$temp_output" "$error_file" runs on every return path.

- In src/git_analyzer.sh around lines 60 to 69, the extension-to-file_type mapping in the case "${filename##*.}" lacks C/C++ branches so .c/.cpp files fall back to "text"; add branches so ".c)" sets file_type="c" and ".cpp|cc|cxx)" sets file_type="c++", and then run tests and update tests/test_git_analyzer.sh around lines 109 to 113 to match the expected values (e.g., assert_contains "$result" "c" for .c files or "c++" for .cpp files) so implementation and tests are consistent.

- In src/ui_helper.sh around lines 37 (also apply same change at 68 and 191), tput currently writes its ANSI cursor-control sequence to stdout which mixes with command output; change the tput invocations so their output goes to the terminal/TTY or stderr instead of stdout (for example send stdout to stderr or /dev/tty and still suppress tput errors), and ensure the cleanup/display messages are printed to stderr as well so all UI control sequences are kept off stdout and do not interleave with program output.

- In src/ui_helper.sh around lines 216-218 (also apply same change at 234-235 and 255-257): the current trap overwrites global EXIT/INT/TERM handlers and later clears them with `trap - EXIT INT TERM`, disabling the previously registered cleanup_ui; change the local traps so EXIT is not touched, set a trap only for INT and TERM that stops the spinner and removes the temp file (so cleanup_ui remains intact on EXIT), and when tearing down restore only INT/TERM (use `trap - INT TERM` or equivalent) instead of clearing EXIT.

- In src/ui_helper.sh around lines 269 to 274, wrap the read calls in a negated conditional (if ! read ...; then ...) so read failures (e.g. EOF/Ctrl-D) are handled instead of letting set -e abort the script; on failure explicitly set input to the default (if provided) or to an empty string and optionally print a newline or warning, then continue execution. Ensure both branches (with and without default_value) use this guarded read pattern and do not allow an unhandled read failure to propagate.