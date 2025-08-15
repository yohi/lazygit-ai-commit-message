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

- In src/ui_helper.sh around lines 269 to 274, wrap the read calls in a negated conditional (if ! read ...; then ...) so read failures (e.g. EOF/Ctrl-D) are handled instead of letting set -e abort the script; on failure explicitly set input to the default (if provided) or to an empty string and optionally print a newline or warning, then continue execution. Ensure both branches (with and without default_value) use this guarded read pattern and do not allow an unhandled read failure to propagate.