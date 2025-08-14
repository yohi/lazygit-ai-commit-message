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

- In ai-commit-generator around line 206, the script invokes jq directly (echo "$file_analysis" | jq .) which will fail if jq is not installed; modify the script to first check for jq availability (e.g., command -v jq >/dev/null) and if present use jq, otherwise fall back to a portable alternative (for example use python -m json.tool or print the raw JSON) and/or emit a clear error message instructing the user to install jq; ensure the fallback preserves readable output in dry-run mode and that the script exits or continues gracefully when jq is absent.

- In scripts/debug_gemini.sh around lines 18 to 22, avoid using which and unquoted command substitution which triggers ShellCheck SC2046; instead use command -v to detect the gemini binary, assign its path to a variable, check for empty (not found) and branch accordingly, quote variable expansions when passing to ls (e.g. ls -la "$gemini_path"), and keep error redirection (2>/dev/null) on the commands rather than inside unquoted substitutions so the script prints a clear "NOT FOUND" / "バージョン取得失敗" / "ファイル情報取得失敗" message when appropriate.

- In scripts/debug_gemini.sh around lines 25-34 (and also apply the same change to lines 102-103), the script currently prints API key length and slices (prefix/suffix), which risks leaking secret material; change the output to only report presence or absence of GEMINI_API_KEY (e.g., "設定状況: ✅ 設定済み" or "設定状況: ❌ 未設定") and remove any printing of the key, its length, or any substrings; keep the export hint only when not set and ensure no other lines log key contents.

- In scripts/install.sh around lines 137 to 139, the script currently does a blind cp -r "$PROJECT_DIR/config" "$CONFIG_DIR/" which can overwrite an existing user config; change this to detect whether "$CONFIG_DIR/config" exists and if so create a timestamped backup (e.g., move or tar it to a backup location), then merge or copy without clobbering user changes (use rsync -a --backup or rsync -a --ignore-existing to preserve existing files, or prompt for overwrite), otherwise perform the copy; ensure permissions and ownership are preserved and that error handling/log messages are added for backup/merge outcomes.

- In scripts/test_gemini.sh around lines 33 to 41, do not print any part of GEMINI_API_KEY (remove the echo of the prefix) because that risks secret leakage; instead only log that the key is set and optionally its length (no substring), and if GEMINI_API_KEY is not set print the error and exit non‑zero immediately to fail early; ensure no other code prints or logs the key value.

- In scripts/test_gemini.sh around lines 44-53 (and similarly apply to 60-63 and 69-72), tests call the gemini CLI directly and can hang; add a small wrapper function that checks for the presence of the timeout command (e.g., command -v timeout >/dev/null) and, if available, prepends a reasonable timeout (like timeout 30s) to the command invocation, otherwise runs the command unchanged; replace direct gemini calls with this wrapper while preserving exit codes and stdout/stderr forwarding so the script behaves identically when timeout is absent and uses the timeout when present.

- In scripts/test_simple_gemini.sh around lines 18 to 23, the script assumes the gemini CLI is installed and will fail later if it's missing; add an explicit existence check at the top of this block: use command -v gemini >/dev/null 2>&1 (or which gemini) to detect absence, print a clear error message to stderr like "gemini not found; please install gemini" and exit with a non-zero status (e.g., exit 1) so the script fails fast and clearly when the binary is not installed.

- In scripts/test_simple_gemini.sh around lines 37 to 41, the script prints an error when an empty message is detected but still exits with status 0; change the error branch to call exit 1 after printing the error so the CI fails, i.e., keep the existing error echo and append a non-zero exit (exit 1) in that else block, leaving the success branch unchanged.

- In scripts/test_simple_gemini.sh around lines 42 to 45, the failure branch currently prints error messages but does not set a non-zero exit code; modify the else block to exit with a non-zero status (e.g., add exit 1 after the echo lines) so callers can detect failure reliably.

- In src/config_loader.sh around lines 136-137, 158, 162, 220, and 231-232, split combined local-declaration-and-assignment statements into separate declaration and assignment so command failures are not hidden; declare the local variable first (local var), then assign with a guarded command substitution (capture exit status) and handle errors (e.g., if the command fails, return/exit or log and return a non-zero status) to ensure failures are detected and propagated.

- In src/config_loader.sh around line 257, the script pipes load_config directly into jq which will fail if jq is not installed; modify this to first capture the output of load_config, check for jq with command -v or type, and if jq exists pipe the captured output to jq ., otherwise write a concise warning to stderr about jq being unavailable and print the raw load_config output (or a safe fallback) so the command does not error out; ensure the original exit status/behavior is preserved.

- In src/error_handler.sh around lines 41 to 201, the case patterns use unquoted variable expansions (e.g. ${ERROR_CODES["..."]}) which can trigger ShellCheck SC2254 and allow unwanted globbing; update each case label to use quoted expansions (e.g. "${ERROR_CODES["..."]}") so the match is literal, and apply this change consistently to all case patterns in this block.

- In src/error_handler.sh around lines 324 to 334, the ERR trap won't be inherited by functions and subshells because errtrace isn't enabled; update the shell options to enable errtrace by adding set -E (or set -o errtrace) alongside the existing set -euo pipefail (e.g., change to set -Eeuo pipefail or add a separate set -o errtrace) so the trap is propagated into functions and subshells.

- In src/gemini_client.sh around lines 67 to 72, get_gemini_command() is defined but not used inside call_gemini_cli; update call_gemini_cli to invoke the function instead of hardcoding the binary so future overrides or configuration take effect. Replace any direct "gemini" invocation in call_gemini_cli with "$(get_gemini_command)" (or use command substitution without quotes if the call needs word-splitting), forward all original arguments and stdin/prompts as before, and ensure the function is available in the script scope (export or source if necessary).

- In src/gemini_client.sh around lines 222 to 229, the code assumes jq is installed when extracting config values; add a jq-availability check and fall back to defaults when jq is missing. Implement: call load_config into a variable, test with "command -v jq >/dev/null 2>&1"; if jq exists keep the current jq parses, otherwise extract values from the JSON string using simple shell-safe fallbacks (e.g., use parameter expansion, grep/sed/awk to pull keys, or just assign the default literals shown now) so model, temperature, max_tokens, timeout, language, and max_length are set to the same defaults when jq is absent.

- In src/gemini_client.sh around lines 238 to 244, the current code does command substitution then checks $? which is unreliable under set -e; change the pattern to perform the command substitution inside an explicit negated conditional (e.g. if ! response=$(call_gemini_cli "$prompt" "$model" "$temperature" "$max_tokens" "$timeout"); then return 1; fi) so that failures in the substitution are detected deterministically and the function returns the proper non-zero status.

- In src/git_analyzer.sh around line 91, the heredoc assignment currently declares and assigns the local variable in one statement which can hide the cat command's exit status; split the declaration and assignment into two steps (declare the local variable first, then assign to it with the heredoc command substitution) so the command's exit code is not masked and ShellCheck warning is resolved.

- In src/logger.sh around lines 25 and 28, the current code uses combined declaration-and-assignment (e.g., local var=$(command)) which can hide the command's exit status; split declaration and assignment into two statements by first declaring the local variable (local timestamp) and then assigning the value on the next line (timestamp=$(date ...)), and do the same for the other occurrence on line 28 so command failures are not masked.

- In src/ui_helper.sh around lines 17-19 (and similarly 54-56), the code uses jq directly to read config values which breaks in environments without jq; replace these direct jq calls with the existing get_config_value function to retrieve ui.show_spinner (and other UI settings), i.e., call get_config_value with the loaded config and a key fallback, parse its output to a boolean defaulting to true, and remove direct jq usage so the function works whether or not jq is installed.

- In src/ui_helper.sh around lines 17-18 (and also apply the same change at 54-55), do not combine local declaration and command substitution on one line; instead declare the variables first (e.g., local config) and then assign the command results on the next line (e.g., config=$(load_config)) to avoid hiding function return values and satisfy ShellCheck; repeat the same pattern for show_spinner (declare local show_spinner, then set show_spinner=$(echo "$config" | jq -r '...')).

- In tests/test_git_analyzer.sh around lines 66 to 77, the test repo setup uses a manually constructed /tmp path and cd which is unsafe and may not restore CWD; replace that with mktemp -d to create a secure temporary directory and use pushd before changing into it and popd at the end (or ensure a trap to popd/cleanup) so the working directory is always restored and the temp directory is unique and securely created; also ensure the function echoes the temp path and cleans up on exit.

- In scripts/install.sh around lines 265 to 273, the interactive read can fail (EOF/Ctrl-D) under set -e and terminate the script; change the read handling to avoid exiting on failure by capturing read's exit and treating empty or failed reads as a negative response. Concretely, run the read in a guarded way (e.g. temporarily disable errexit or append "|| REPLY=''" to the read, or use "if ! read -r ...; then REPLY=''; fi"), then test REPLY against ^[Yy]$ and only remove CONFIG_DIR when it matches, otherwise log that it was kept.

- In scripts/install.sh around lines 279 to 289, the interactive read prompting to remove Lazygit AI Commit Generator settings must be guarded for non-interactive runs; only prompt when stdin is a TTY and otherwise default to "no". Modify the block so you first check if stdin is a terminal (e.g., [ -t 0 ]), perform read -p only when true, and set REPLY="N" (or equivalent default) when not a TTY; keep the backup, sed removal, and log behavior unchanged but only execute them when REPLY matches ^[Yy]$.

- In src/gemini_client.sh around lines 90 to 101 (and also update usages at ~140 and ~252), add a portable timeout command detection at the top of the script that sets a variable (e.g. timeout_cmd) to 'timeout' if available, otherwise to 'gtimeout' if available, and fail with a clear error if neither exists; then replace direct calls to timeout in the noted locations with the detected variable (e.g. "$timeout_cmd" ...) so macOS Homebrew gtimeout is used when present and Linux timeout remains unchanged.

- In src/ui_helper.sh around lines 16 to 23, remove the unnecessary here-string and duplicate load_config call: delete the config=$(load_config) assignment and the <<< "$config" on the get_config_value call so it becomes show_spinner=$(get_config_value ".ui.show_spinner" "true"), and adjust the surrounding logic accordingly; apply the same change in the show_confirmation implementation so you don't call load_config twice and avoid passing a useless heredoc to get_config_value.

- In src/ui_helper.sh around lines 27 to 39, the spinner currently writes to stdout and doesn't hide/restore the cursor; change it to hide the cursor before starting (e.g. tput civis or ESC sequence), run the spinner loop printing to stderr (redirect printf/sleep output to >&2) in the background, capture its PID in SPINNER_PID, and ensure you restore the cursor (tput cnorm or ESC) and kill the spinner on exit (use a trap or ensure callers restore on stop) so spinner output won't mix with command stdout and the terminal cursor is always restored.

- In src/ui_helper.sh around lines 41 to 50, stop_spinner currently kills and waits for the spinner process but does not reliably clear the current line or restore the cursor visibility; update stop_spinner to, after killing/waiting and before logging, clear the line (e.g. overwrite with a carriage return plus ANSI clear-line sequence) and restore cursor visibility (use tput cnorm if available, otherwise emit the ANSI show-cursor sequence), then reset SPINNER_PID and log; ensure these extra steps run unconditionally when a spinner was running so the UI is restored even if cleanup_ui is not called.