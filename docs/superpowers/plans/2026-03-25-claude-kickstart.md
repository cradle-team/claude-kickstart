# claude-kickstart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code環境を対話式ヒアリングでパーソナライズし、ワンライナーでセットアップできるインストーラーを構築する

**Architecture:** bashスクリプト（install.sh）がメインエントリポイント。テンプレートファイル群（markdown）をヒアリング結果に基づいて結合・変数置換し、`~/.claude/`配下に配置する。settings.jsonのマージにはjqを使用。

**Tech Stack:** Bash, jq, Git, GitHub Actions（チェックサム生成）

**Spec:** `docs/superpowers/specs/2026-03-24-claude-kickstart-design.md`（ホームディレクトリ配下）

---

### Task 1: プロジェクトスキャフォールド

**Files:**
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `plugins.txt`
- Create: `templates/` (ディレクトリ構造)

- [ ] **Step 1: ディレクトリ構造を作成**

```bash
mkdir -p templates/{claude-md,agents,rules,hooks,examples}
```

- [ ] **Step 2: LICENSE（MIT）を作成**

```
MIT License

Copyright (c) 2026 Cradle Inc. (crdl.co.jp)

Permission is hereby granted...
```

- [ ] **Step 3: .gitignoreを作成**

```
.DS_Store
node_modules/
*.log
```

- [ ] **Step 4: plugins.txtを作成**

```
superpowers@claude-plugins-official
pr-review-toolkit@claude-plugins-official
frontend-design@claude-plugins-official
code-simplifier@claude-plugins-official
```

- [ ] **Step 5: 初期コミット**

```bash
git add -A
git commit -m "chore: initial project scaffold"
```

---

### Task 2: CLAUDE.mdテンプレートパーツ（基本）

**Files:**
- Create: `templates/claude-md/header.md`
- Create: `templates/claude-md/base-rules.md`
- Create: `templates/claude-md/verification.md`

- [ ] **Step 1: header.mdを作成**

ヒアリング変数のプレースホルダーを含むUser Contextテンプレート:
```markdown
# User Context

{{USER_NAME}}。{{COMPANY_NAME}}の{{ROLE_LABEL}}。
{{ROLE_DESCRIPTION}}

## Tech Stack
{{TECH_STACK_LIST}}
```

- [ ] **Step 2: base-rules.mdを作成**

スペックの `base-rules.md` セクション通り。`{{PKG_MANAGER}}` プレースホルダーを含む。

- [ ] **Step 3: verification.mdを作成**

スタック別マッピングのプレースホルダーではなく、install.sh側で動的生成するための**テンプレートヘッダーのみ**:
```markdown
# 検証コマンド

コード変更後は必ず該当する検証を実行しろ:
```
（検証コマンドリストはinstall.shが動的に追記する）

- [ ] **Step 4: コミット**

```bash
git add templates/claude-md/header.md templates/claude-md/base-rules.md templates/claude-md/verification.md
git commit -m "feat: add base CLAUDE.md template parts"
```

---

### Task 3: CLAUDE.mdテンプレートパーツ（スタック別）

**Files:**
- Create: `templates/claude-md/stack-nextjs.md`
- Create: `templates/claude-md/stack-react-native.md`
- Create: `templates/claude-md/stack-vue.md`
- Create: `templates/claude-md/stack-python.md`
- Create: `templates/claude-md/stack-rails.md`
- Create: `templates/claude-md/stack-go.md`
- Create: `templates/claude-md/stack-swift.md`
- Create: `templates/claude-md/stack-flutter.md`

- [ ] **Step 1: stack-nextjs.mdを作成**

スペック通り。App Router、Server Components、use client、useEffect、Next.js最適化コンポーネント。

- [ ] **Step 2: stack-react-native.mdを作成**

```markdown
## React Native / Expo
- Expo Routerを使用する場合はファイルベースルーティングのルールに従え
- ネイティブモジュールが必要な場合はExpo Dev Clientを使え
- プラットフォーム固有のコードは `.ios.tsx` / `.android.tsx` で分離
- パフォーマンスが問題になるリストは `FlashList` を検討しろ
```

- [ ] **Step 3: stack-vue.mdを作成**

```markdown
## Vue / Nuxt
- Composition APIを使え。Options APIは新規コードでは使うな
- `<script setup>` 構文を推奨
- Nuxtの場合はauto-importを活用しろ
- リアクティビティの落とし穴に注意: `ref` vs `reactive` を正しく使い分けろ
```

- [ ] **Step 4: stack-python.mdを作成**

```markdown
## Python
- 型ヒントを必ず書け（Python 3.10+ の `|` 構文推奨）
- フォーマッターは `ruff format`、リンターは `ruff check` を使え
- 仮想環境は必須。`venv` か `poetry` を使え
- FastAPI使用時はPydanticモデルでリクエスト/レスポンスを型定義しろ
```

- [ ] **Step 5: stack-rails.md, stack-go.md, stack-swift.md, stack-flutter.mdを作成**

各スタック固有のベストプラクティス（5-8行程度）。

- [ ] **Step 6: コミット**

```bash
git add templates/claude-md/stack-*.md
git commit -m "feat: add stack-specific CLAUDE.md template parts"
```

---

### Task 4: CLAUDE.mdテンプレートパーツ（DB別 + ワークフロー別）

**Files:**
- Create: `templates/claude-md/db-supabase.md`
- Create: `templates/claude-md/db-firebase.md`
- Create: `templates/claude-md/db-postgres.md`
- Create: `templates/claude-md/workflow-solo.md`
- Create: `templates/claude-md/workflow-lead.md`
- Create: `templates/claude-md/workflow-member.md`
- Create: `templates/claude-md/workflow-non-eng.md`

- [ ] **Step 1: db-supabase.mdを作成**

スペック通り（RLS必須、anon key最小化、service_role漏洩防止）。

- [ ] **Step 2: db-firebase.mdを作成**

```markdown
## Firebase
- Firestore Security Rulesは必ず設定しろ。テストモードのまま本番に出すな
- クライアントサイドにAdmin SDKのサービスアカウントキーを絶対置くな
- Firestoreのクエリはインデックスを意識しろ
- Cloud Functionsは冪等に設計しろ
```

- [ ] **Step 3: db-postgres.mdを作成**

```markdown
## PostgreSQL
- マイグレーションは必ずバージョン管理しろ
- 本番DBに直接ALTER TABLEを打つな。マイグレーションファイルを通せ
- インデックスは必要なクエリに対して適切に設定しろ
- N+1クエリに注意。JOINかバッチ取得を使え
```

- [ ] **Step 4: workflow-solo.md, workflow-lead.md, workflow-member.md, workflow-non-eng.mdを作成**

スペックの各ROLE別テンプレート通り。

- [ ] **Step 5: コミット**

```bash
git add templates/claude-md/db-*.md templates/claude-md/workflow-*.md
git commit -m "feat: add DB and workflow CLAUDE.md template parts"
```

---

### Task 5: Agentテンプレート

**Files:**
- Create: `templates/agents/code-reviewer.md`
- Create: `templates/agents/debugger.md`
- Create: `templates/agents/test-writer.md`
- Create: `templates/agents/security-reviewer.md`
- Create: `templates/agents/typescript-reviewer.md`
- Create: `templates/agents/architect.md`

- [ ] **Step 1: いっきさんの既存agentをコピーしてテンプレート化**

ソース: `~/.claude/agents/` の各ファイル。
いっきさん固有の内容（Supabase RLS等）はTypeScript/セキュリティ系のみ残し、他は汎用化する。

- [ ] **Step 2: 各agentファイルを作成**

6ファイル。既存の `~/.claude/agents/` からベースを取り、汎用化。

- [ ] **Step 3: コミット**

```bash
git add templates/agents/
git commit -m "feat: add agent templates"
```

---

### Task 6: Rulesテンプレート

**Files:**
- Create: `templates/rules/dev-workflow.md`
- Create: `templates/rules/agent-team.md`
- Create: `templates/rules/codex.md`

- [ ] **Step 1: dev-workflow.mdを作成**

`~/.claude/rules/workflow.md` をベースに汎用化（WBS、planning-with-files等）。

- [ ] **Step 2: agent-team.mdを作成**

`~/.claude/rules/agent-team.md` をベースに。パイプラインパターンを含む。

- [ ] **Step 3: codex.mdを作成**

`~/.claude/rules/codex.md` をベースに。`{{CWD_PLACEHOLDER}}` を含め、install.sh側で注意書きを追加。

- [ ] **Step 4: コミット**

```bash
git add templates/rules/
git commit -m "feat: add rules templates"
```

---

### Task 7: パイプライン例テンプレート

**Files:**
- Create: `templates/examples/pipeline-content.md`
- Create: `templates/examples/pipeline-feature.md`

- [ ] **Step 1: pipeline-content.mdを作成**

コンテンツ制作パイプラインの具体的な実行手順。各Stage、Worker/Manager、採点基準、差し戻しフロー。

- [ ] **Step 2: pipeline-feature.mdを作成**

機能開発パイプラインの具体的な実行手順。Architect→Coder→Security Reviewerの3ステージ。

- [ ] **Step 3: コミット**

```bash
git add templates/examples/
git commit -m "feat: add pipeline example templates"
```

---

### Task 8: settings.json.base + hookスクリプト

**Files:**
- Create: `templates/settings.json.base`
- Create: `templates/hooks/session-start.sh`
- Create: `templates/hooks/block-no-verify.sh`
- Create: `templates/hooks/block-config-edit.sh`
- Create: `templates/hooks/block-unnecessary-docs.sh`
- Create: `templates/hooks/auto-format.sh`
- Create: `templates/hooks/typecheck.sh`
- Create: `templates/hooks/console-log-check.sh`
- Create: `templates/hooks/pre-compact.sh`
- Create: `templates/hooks/stop-console-check.sh`
- Create: `templates/hooks/subagent-quality.sh`

- [ ] **Step 1: settings.json.baseを作成**

いっきさんの `~/.claude/settings.json` をベースに、個人固有の設定（enabledPlugins, extraKnownMarketplaces, language, statusLine等）を除外。hooks内のインラインスクリプトを外部ファイル参照に変更。deny list、permissions構造を含む。

hookの `command` フィールドは外部シェルスクリプトを参照する形にする:
```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/block-no-verify.sh"
}
```

- [ ] **Step 2: 各hookスクリプトを作成**

いっきさんのsettings.jsonに埋め込まれている各hookのインラインスクリプトを、個別の `.sh` ファイルに分離。先頭に `#!/usr/bin/env bash` と `set -euo pipefail` を配置。

10ファイル。各ファイルは `stdin` からJSONを受け取り、処理後に `stdout` に出力する形式。

- [ ] **Step 3: コミット**

```bash
git add templates/settings.json.base templates/hooks/
git commit -m "feat: add settings.json base and hook scripts"
```

---

### Task 9: install.sh — Phase 0（前提チェック）

**Files:**
- Create: `install.sh`

- [ ] **Step 1: install.shのシェバンとフラグ処理を作成**

```bash
#!/usr/bin/env bash
set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# フラグ
DRY_RUN=false
ROLLBACK=false
RECONFIGURE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --rollback) ROLLBACK=true; shift ;;
    --reconfigure) RECONFIGURE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done
```

- [ ] **Step 2: SCRIPT_DIR取得（curl|bash対応）**

`curl | bash` で実行された場合、テンプレートファイルをGitHubから取得する必要がある。ローカル実行（`git clone` 後）の場合はローカルファイルを使用。

```bash
if [ -f "$(dirname "$0")/templates/settings.json.base" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  SOURCE="local"
else
  SCRIPT_DIR=$(mktemp -d)
  SOURCE="remote"
  REPO_URL="https://raw.githubusercontent.com/crdl-co/claude-kickstart/main"
  # テンプレートファイルをダウンロード
fi
```

- [ ] **Step 3: OS検出と前提チェック関数を実装**

```bash
detect_os() { ... }       # uname -s → darwin/linux
check_node() { ... }      # node --version >= 18
check_git() { ... }       # git --version
check_claude() { ... }    # claude --version
check_jq() { ... }        # jq --version
install_missing() { ... } # OS別インストールガイド
```

- [ ] **Step 4: --rollback処理を実装**

```bash
if [ "$ROLLBACK" = true ]; then
  latest_backup=$(ls -t ~/.claude/backups/settings.json.* 2>/dev/null | head -1)
  # バックアップから復元
  exit 0
fi
```

- [ ] **Step 5: テスト — install.sh --dry-run で Phase 0 が通ることを確認**

```bash
bash install.sh --dry-run
```
Expected: 前提チェック結果が表示され、ヒアリングに進む

- [ ] **Step 6: コミット**

```bash
git add install.sh
git commit -m "feat: install.sh Phase 0 - prerequisite checks"
```

---

### Task 10: install.sh — Phase 1（ヒアリング）

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: ヒアリング関数群を実装**

```bash
ask_name() { ... }        # Q1
ask_company() { ... }     # Q2
ask_role() { ... }        # Q3
ask_stacks() { ... }      # Q4（複数選択対応）
ask_db() { ... }          # Q5
ask_pkg_manager() { ... } # Q6
ask_codex() { ... }       # Q7
ask_team() { ... }        # Q8
```

各関数はreadで入力を受け取り、グローバル変数に格納。

- [ ] **Step 2: kickstart-config.json の読み込み/保存を実装**

```bash
load_config() {
  if [ -f ~/.claude/kickstart-config.json ] && [ "$RECONFIGURE" = false ]; then
    # 既存config読み込み、ヒアリングスキップ確認
  fi
}
save_config() {
  # 回答をJSON形式で保存
  jq -n \
    --arg name "$USER_NAME" \
    --arg company "$COMPANY_NAME" \
    ... \
    '{name: $name, company: $company, ...}' > ~/.claude/kickstart-config.json
}
```

- [ ] **Step 3: テスト — ヒアリングが正しく変数に格納されること**

```bash
bash install.sh --dry-run
# Q1-Q8に回答し、最後にサマリーが表示されることを確認
```

- [ ] **Step 4: コミット**

```bash
git add install.sh
git commit -m "feat: install.sh Phase 1 - interactive interview"
```

---

### Task 11: install.sh — Phase 2（設定生成）

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: CLAUDE.md生成関数を実装**

```bash
generate_claude_md() {
  local output="$1"

  # header — 変数置換
  sed "s/{{USER_NAME}}/$USER_NAME/g; s/{{COMPANY_NAME}}/$COMPANY_NAME/g; ..." \
    "$TEMPLATE_DIR/claude-md/header.md" > "$output"

  # base-rules — PKG_MANAGER置換
  sed "s/{{PKG_MANAGER}}/$PKG_MANAGER/g" \
    "$TEMPLATE_DIR/claude-md/base-rules.md" >> "$output"

  # stack-*.md — 選択に応じて結合
  IFS=',' read -ra stacks <<< "$STACKS"
  for stack in "${stacks[@]}"; do
    if [ -f "$TEMPLATE_DIR/claude-md/stack-${stack}.md" ]; then
      cat "$TEMPLATE_DIR/claude-md/stack-${stack}.md" >> "$output"
    fi
  done

  # db-*.md
  if [ -f "$TEMPLATE_DIR/claude-md/db-${DB}.md" ]; then
    cat "$TEMPLATE_DIR/claude-md/db-${DB}.md" >> "$output"
  fi

  # workflow
  cat "$TEMPLATE_DIR/claude-md/workflow-${ROLE}.md" >> "$output"

  # verification — 動的生成
  generate_verification >> "$output"
}
```

- [ ] **Step 2: verification動的生成を実装**

スタック別コマンドマッピング表に基づいて検証コマンドリストを生成:

```bash
generate_verification() {
  echo ""
  echo "# 検証コマンド"
  echo ""
  echo "コード変更後は必ず該当する検証を実行しろ:"

  IFS=',' read -ra stacks <<< "$STACKS"
  for stack in "${stacks[@]}"; do
    case "$stack" in
      nextjs)
        echo "- 型チェック: \`$PKG_MANAGER tsc --noEmit\`"
        echo "- リント: \`$PKG_MANAGER lint\`"
        echo "- テスト: \`$PKG_MANAGER test\`"
        echo "- ビルド: \`$PKG_MANAGER build\`"
        ;;
      react-native)
        echo "- 型チェック: \`$PKG_MANAGER tsc --noEmit\`"
        echo "- リント: \`$PKG_MANAGER lint\`"
        echo "- Expo: \`npx expo doctor\`"
        ;;
      # ... 他のスタック
    esac
  done

  case "$DB" in
    supabase) echo "- DB: \`npx supabase db lint\`" ;;
  esac
}
```

- [ ] **Step 3: settings.json生成関数を実装**

条件付きhooks構築。`settings.json.base` をベースに、ヒアリング結果に応じてhooksを追加/除外:

```bash
generate_settings_json() {
  local output="$1"
  local base="$TEMPLATE_DIR/settings.json.base"

  # ベースをコピー
  cp "$base" "$output"

  # TypeScript系がない場合、typecheck/auto-format hookを除外
  if ! has_typescript_stack; then
    jq 'del(.hooks.PostToolUse[] | select(.description | contains("TypeScript")))' \
      "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"
    jq 'del(.hooks.PostToolUse[] | select(.description | contains("Prettier")))' \
      "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"
  fi

  # チーム運用なしの場合、SubagentStop除外
  if [ "$USE_TEAM" != "yes" ]; then
    jq 'del(.hooks.SubagentStop)' "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"
  fi
}
```

- [ ] **Step 4: agents/rules コピー選択関数を実装**

```bash
select_agents() { ... }  # 条件に応じてコピー対象を決定
select_rules() { ... }   # 同上
```

- [ ] **Step 5: テスト — dry-runで生成される内容を確認**

```bash
bash install.sh --dry-run
# 生成されるCLAUDE.md、settings.json、agents、rulesの内容を表示
```

- [ ] **Step 6: コミット**

```bash
git add install.sh
git commit -m "feat: install.sh Phase 2 - configuration generation"
```

---

### Task 12: install.sh — Phase 3（インストール + マージ）

**Files:**
- Modify: `install.sh`
- Create: `merge-settings.sh`

- [ ] **Step 1: バックアップ関数を実装**

```bash
backup_existing() {
  local backup_dir="$HOME/.claude/backups"
  mkdir -p "$backup_dir"
  local timestamp=$(date +%Y%m%d-%H%M%S)

  if [ -f ~/.claude/settings.json ]; then
    cp ~/.claude/settings.json "$backup_dir/settings.json.$timestamp"
  fi

  # 5世代以上あれば古いものを削除
  ls -t "$backup_dir"/settings.json.* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
}
```

- [ ] **Step 2: merge-settings.shを作成**

スペック記載のjqカスタムマージロジック。permissions.allow/deny + hooks各イベントを配列レベルでマージ。

- [ ] **Step 3: ファイル配置関数を実装**

```bash
install_files() {
  # CLAUDE.md
  if [ -f ~/CLAUDE.md ]; then
    # diff表示 + 上書き/スキップ/マージ選択
  else
    cp "$GENERATED_CLAUDE_MD" ~/CLAUDE.md
  fi

  # agents
  mkdir -p ~/.claude/agents
  for agent in $SELECTED_AGENTS; do
    if [ -f ~/.claude/agents/"$agent" ]; then
      # 上書き確認
    fi
    cp "$TEMPLATE_DIR/agents/$agent" ~/.claude/agents/
  done

  # rules, hooks, examples 同様
}
```

- [ ] **Step 4: settings.jsonマージの実行**

```bash
if [ -f ~/.claude/settings.json ]; then
  bash merge-settings.sh ~/.claude/settings.json "$GENERATED_SETTINGS" > /tmp/kickstart-merged.json
  mv /tmp/kickstart-merged.json ~/.claude/settings.json
else
  cp "$GENERATED_SETTINGS" ~/.claude/settings.json
fi
```

- [ ] **Step 5: プラグインインストールを実装**

```bash
install_plugins() {
  while IFS= read -r plugin; do
    echo -e "  ${BLUE}Installing${NC} $plugin..."
    claude plugin add "$plugin" 2>/dev/null || echo -e "  ${YELLOW}Skipped${NC} $plugin (already installed or unavailable)"
  done < "$SCRIPT_DIR/plugins.txt"
}
```

- [ ] **Step 6: AgentShieldインストール + スキャン**

```bash
install_agentshield() {
  if ! npm list -g ecc-agentshield >/dev/null 2>&1; then
    npm install -g ecc-agentshield
  fi
  npx ecc-agentshield scan --path ~/.claude 2>&1 | tail -5
}
```

- [ ] **Step 7: テスト — 実際にインストール実行（テスト用ホームディレクトリで）**

```bash
HOME=/tmp/kickstart-test bash install.sh
# /tmp/kickstart-test/.claude/ 配下に正しくファイルが配置されることを確認
```

- [ ] **Step 8: コミット**

```bash
git add install.sh merge-settings.sh
git commit -m "feat: install.sh Phase 3 - installation and merge"
```

---

### Task 13: install.sh — Phase 4（完了サマリー）+ リモートテンプレート取得

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: 完了サマリー表示関数を実装**

スペック通りのサマリー表示。ヒアリング回答、生成ファイル一覧、セキュリティ結果、次のステップを表示。

- [ ] **Step 2: リモートテンプレート取得を実装（curl|bash対応）**

`curl | bash` で実行された場合にGitHub rawからテンプレートをダウンロードする処理:

```bash
download_templates() {
  local base_url="https://raw.githubusercontent.com/crdl-co/claude-kickstart/main"
  local files=(
    "templates/settings.json.base"
    "templates/claude-md/header.md"
    "templates/claude-md/base-rules.md"
    # ... 全テンプレートファイル
    "plugins.txt"
    "merge-settings.sh"
  )

  for f in "${files[@]}"; do
    mkdir -p "$SCRIPT_DIR/$(dirname "$f")"
    curl -sL "$base_url/$f" -o "$SCRIPT_DIR/$f"
  done
}
```

- [ ] **Step 3: テスト — フルフローをdry-runで実行**

```bash
bash install.sh --dry-run
```
Expected: Phase 0-4が全て通り、サマリーが表示される

- [ ] **Step 4: コミット**

```bash
git add install.sh
git commit -m "feat: install.sh Phase 4 - summary and remote template download"
```

---

### Task 14: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: README.mdを作成**

日本語。以下のセクション:
- ワンライナーインストール方法
- 安全なインストール方法（チェックサム検証）
- 何がインストールされるか
- ヒアリングの流れ
- カスタマイズ方法
- フラグ一覧（--dry-run, --rollback, --reconfigure）
- アンインストール方法
- ライセンス

- [ ] **Step 2: コミット**

```bash
git add README.md
git commit -m "docs: add README with installation guide"
```

---

### Task 15: 統合テスト + 最終調整

**Files:**
- Modify: 各ファイル（必要に応じて）

- [ ] **Step 1: クリーンな環境でフルインストールテスト**

```bash
# テスト用のホームディレクトリでフルフロー実行
export HOME=/tmp/kickstart-test-$(date +%s)
mkdir -p "$HOME"
bash install.sh
```

全Phase通過、ファイルが正しく配置されることを確認。

- [ ] **Step 2: べき等性テスト**

```bash
# 2回実行して壊れないことを確認
bash install.sh  # 1回目
bash install.sh  # 2回目 — 上書き確認が出て、スキップしても壊れない
```

- [ ] **Step 3: settings.jsonマージテスト**

既存のsettings.jsonがある状態でinstall.shを実行し、既存のhooksが消えないことを確認。

- [ ] **Step 4: --rollbackテスト**

```bash
bash install.sh --rollback
# 直前のバックアップに戻ることを確認
```

- [ ] **Step 5: 問題があれば修正**

- [ ] **Step 6: 最終コミット**

```bash
git add -A
git commit -m "test: integration testing and final adjustments"
```

---

### Task 16: GitHub公開準備

**Files:**
- Create: `.github/workflows/checksum.yml`（将来用）

- [ ] **Step 1: GitHub リポジトリ作成**

```bash
gh repo create crdl-co/claude-kickstart --public --source=. --remote=origin --push
```

- [ ] **Step 2: チェックサム生成用のGitHub Actions（将来用、placeholder）**

今は手動でチェックサム生成。GA設定は後回し。

```bash
shasum -a 256 install.sh > checksums.txt
git add checksums.txt
git commit -m "chore: add initial checksum"
```

- [ ] **Step 3: 動作確認 — ワンライナーでインストールできることを確認**

```bash
curl -sL https://raw.githubusercontent.com/crdl-co/claude-kickstart/main/install.sh | bash
```

- [ ] **Step 4: 完了**
