# Cloud source handoff

This is a snapshot of the latest Windows working tree, NOT GitHub main.
Baseline: c06b546eb0597c1651b097b59813902b734b1120
Repository: https://github.com/GitLeeGH/take_care_refrigerator

Extract into a NEW directory; do not overwrite unrelated cloud work. No .git history included.
Use the manifest to verify each file. All nonignored tracked/untracked source is included except documented exclusions. Android Gradle wrapper scripts/JAR are included from ignored local files.

Requires Flutter/Dart compatible with pubspec.yaml (Dart >=3.9). Read pubspec.lock before dependency changes. Copy .env.example to .env; empty fixture suffices for mocked tests. Configure only public client URL/key through approved channel for actual backend access. Never put server secrets in Flutter.
Run flutter pub get, flutter test, and node tool/test_player_segments.cjs when runtimes are available. Android needs JDK/SDK; Windows PC SDKs/caches/signing are NOT included. No release signing credentials included. Regenerate plugin files via Flutter tooling as needed.

SQL history includes applied migrations and DRAFT SQL. DO NOT execute drafts or reapply history to the live backend. The source files do not contain a full database backup. Later server recipe inserts/segment migration may not all have local migration files.

The manual tool/public_ten_recipes_check.dart requires ../public_ten_recipe_checks.json, intentionally NOT transferred (live data snapshot). It is not part of default tests. Screenshot tests may require their documented output directories/viewport.

Excluded legacy reg/error screenshots may affect documentation screenshots only; app icon assets are retained. Local editor settings replaced with empty object. Public Kakao identifiers, if detected, are replaced in archive copies only; configure correctly before social login tests. No real login, account actions, DB writes, push, or deploy performed.

Secret scan covers known private key/token patterns and credential assignments, plus denylisted filenames. It is a heuristic, not proof of absence of every possible secret. Original PC files are untouched.
