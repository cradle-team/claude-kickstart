#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# claude-kickstart — Claude Code環境セットアップインストーラー
# https://github.com/crdl-co/claude-kickstart
# ============================================================

VERSION="1.0.0"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Flags ---
DRY_RUN=false
ROLLBACK=false
RECONFIGURE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --rollback) ROLLBACK=true; shift ;;
    --reconfigure) RECONFIGURE=true; shift ;;
    --version) echo "claude-kickstart v$VERSION"; exit 0 ;;
    --help) 
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run       プレビューモード（ファイルを書き込まない）"
      echo "  --rollback      直前のバックアップに復元"
      echo "  --reconfigure   ヒアリングをやり直す"
      echo "  --version       バージョン表示"
      echo "  --help          このヘルプを表示"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

# --- Template Source ---
# Detect if running from local clone or via curl|bash
if [ -f "$(dirname "${BASH_SOURCE[0]:-$0}")/templates/settings.json.base" ] 2>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  SOURCE="local"
else
  SCRIPT_DIR=$(mktemp -d)
  SOURCE="remote"
  REPO_URL="https://raw.githubusercontent.com/crdl-co/claude-kickstart/main"
  trap "rm -rf $SCRIPT_DIR" EXIT
fi
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# --- Utility Functions ---
info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
error() { echo -e "  ${RED}✗${NC} $1"; }
header() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}\n"; }

ask() {
  local prompt="$1"
  local var_name="$2"
  local default="${3:-}"
  
  if [ -n "$default" ]; then
    echo -en "${BOLD}$prompt${NC} [$default]: "
  else
    echo -en "${BOLD}$prompt${NC}: "
  fi
  read -r answer
  if [ -z "$answer" ] && [ -n "$default" ]; then
    answer="$default"
  fi
  eval "$var_name=\"$answer\""
}

ask_choice() {
  local prompt="$1"
  local var_name="$2"
  shift 2
  local options=("$@")
  
  echo -e "\n${BOLD}$prompt${NC}"
  local i=1
  for opt in "${options[@]}"; do
    local label=$(echo "$opt" | cut -d'|' -f1)
    echo "  $i) $label"
    ((i++))
  done
  echo -en "選択 [1]: "
  read -r choice
  choice=${choice:-1}
  
  local selected="${options[$((choice-1))]}"
  local value=$(echo "$selected" | cut -d'|' -f2)
  eval "$var_name=\"$value\""
}

ask_multi() {
  local prompt="$1"
  local var_name="$2"
  shift 2
  local options=("$@")
  
  echo -e "\n${BOLD}$prompt${NC}（複数選択可、カンマ区切り）"
  local i=1
  for opt in "${options[@]}"; do
    local label=$(echo "$opt" | cut -d'|' -f1)
    echo "  $i) $label"
    ((i++))
  done
  echo -en "選択 [1]: "
  read -r choices
  choices=${choices:-1}
  
  local result=""
  IFS=',' read -ra selected <<< "$choices"
  for idx in "${selected[@]}"; do
    idx=$(echo "$idx" | tr -d ' ')
    local opt="${options[$((idx-1))]}"
    local value=$(echo "$opt" | cut -d'|' -f2)
    if [ -n "$result" ]; then
      result="$result,$value"
    else
      result="$value"
    fi
  done
  eval "$var_name=\"$result\""
}

# ============================================================
# Phase 0: Prerequisites
# ============================================================

phase0_prerequisites() {
  header "claude-kickstart v$VERSION"
  echo "Claude Code環境を最適な状態にセットアップします。"
  
  if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN モード — ファイルは書き込まれません"
  fi
  
  echo ""
  echo -e "${BOLD}[前提チェック中...]${NC}"
  
  local os
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux)  os="linux" ;;
    *)
      error "未対応のOS: $(uname -s)"
      echo "  macOS または Linux のみ対応しています"
      exit 1
      ;;
  esac
  
  # Node.js
  if command -v node >/dev/null 2>&1; then
    local node_version
    node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
    if [ "$node_version" -ge 18 ]; then
      info "Node.js $(node --version)"
    else
      error "Node.js $(node --version) — v18以上が必要です"
      if [ "$os" = "macos" ]; then
        echo "  → brew install node"
      else
        echo "  → curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash && sudo apt install -y nodejs"
      fi
      exit 1
    fi
  else
    error "Node.js が見つかりません"
    if [ "$os" = "macos" ]; then
      echo "  → brew install node"
    else
      echo "  → curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash && sudo apt install -y nodejs"
    fi
    echo ""
    echo -en "インストールしますか？ (Y/n): "
    read -r install_node
    if [[ "$install_node" =~ ^[Nn] ]]; then
      exit 1
    fi
    if [ "$os" = "macos" ]; then
      brew install node || { error "Node.jsのインストールに失敗"; exit 1; }
    else
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install -y nodejs || { error "Node.jsのインストールに失敗"; exit 1; }
    fi
    info "Node.js $(node --version) インストール完了"
  fi
  
  # Git
  if command -v git >/dev/null 2>&1; then
    info "Git $(git --version | awk '{print $3}')"
  else
    error "Git が見つかりません"
    if [ "$os" = "macos" ]; then
      echo "  → xcode-select --install"
    else
      echo "  → sudo apt install -y git"
    fi
    exit 1
  fi
  
  # Claude Code
  if command -v claude >/dev/null 2>&1; then
    info "Claude Code $(claude --version 2>/dev/null || echo 'installed')"
  else
    error "Claude Code が見つかりません"
    echo ""
    echo -en "インストールしますか？ (Y/n): "
    read -r install_claude
    if [[ "$install_claude" =~ ^[Nn] ]]; then
      exit 1
    fi
    npm install -g @anthropic-ai/claude-code || { error "Claude Codeのインストールに失敗"; exit 1; }
    info "Claude Code インストール完了"
  fi
  
  # jq
  if command -v jq >/dev/null 2>&1; then
    info "jq $(jq --version 2>/dev/null || echo 'installed')"
  else
    warn "jq が見つかりません — インストールします"
    if [ "$os" = "macos" ]; then
      brew install jq || { error "jqのインストールに失敗"; exit 1; }
    else
      sudo apt install -y jq || { error "jqのインストールに失敗"; exit 1; }
    fi
    info "jq インストール完了"
  fi
  
  echo ""
  info "前提チェック完了"
}

# ============================================================
# Phase 0.5: Rollback
# ============================================================

handle_rollback() {
  header "ロールバック"
  
  local backup_dir="$HOME/.claude/backups"
  if [ ! -d "$backup_dir" ]; then
    error "バックアップが見つかりません"
    exit 1
  fi
  
  local latest_backup
  latest_backup=$(ls -t "$backup_dir"/settings.json.* 2>/dev/null | head -1)
  
  if [ -z "$latest_backup" ]; then
    error "バックアップが見つかりません"
    exit 1
  fi
  
  echo "復元元: $latest_backup"
  echo -en "復元しますか？ (Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "キャンセルしました"
    exit 0
  fi
  
  cp "$latest_backup" "$HOME/.claude/settings.json"
  info "settings.json を復元しました"
  exit 0
}

# ============================================================
# Phase 1: Interview
# ============================================================

# Config file for re-runs
CONFIG_FILE="$HOME/.claude/kickstart-config.json"

load_config() {
  if [ -f "$CONFIG_FILE" ] && [ "$RECONFIGURE" = false ]; then
    echo ""
    echo -e "前回の設定が見つかりました: ${BLUE}$CONFIG_FILE${NC}"
    echo -en "前回の設定を使いますか？ (Y/n): "
    read -r use_existing
    if [[ ! "$use_existing" =~ ^[Nn] ]]; then
      USER_NAME=$(jq -r '.name // ""' "$CONFIG_FILE")
      COMPANY_NAME=$(jq -r '.company // ""' "$CONFIG_FILE")
      ROLE=$(jq -r '.role // "solo"' "$CONFIG_FILE")
      STACKS=$(jq -r '.stacks // "nextjs"' "$CONFIG_FILE")
      DB=$(jq -r '.db // "supabase"' "$CONFIG_FILE")
      PKG_MANAGER=$(jq -r '.pkg_manager // "pnpm"' "$CONFIG_FILE")
      USE_CODEX=$(jq -r '.use_codex // "no"' "$CONFIG_FILE")
      USE_TEAM=$(jq -r '.use_team // "no"' "$CONFIG_FILE")
      return 0
    fi
  fi
  return 1
}

save_config() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  jq -n \
    --arg name "$USER_NAME" \
    --arg company "$COMPANY_NAME" \
    --arg role "$ROLE" \
    --arg stacks "$STACKS" \
    --arg db "$DB" \
    --arg pkg_manager "$PKG_MANAGER" \
    --arg use_codex "$USE_CODEX" \
    --arg use_team "$USE_TEAM" \
    '{name: $name, company: $company, role: $role, stacks: $stacks, db: $db, pkg_manager: $pkg_manager, use_codex: $use_codex, use_team: $use_team}' \
    > "$CONFIG_FILE"
}

phase1_interview() {
  header "セットアップ"
  
  # Try loading existing config
  if load_config; then
    echo ""
    info "前回の設定を読み込みました"
    echo "  名前: $USER_NAME"
    echo "  会社: $COMPANY_NAME"
    echo "  役割: $ROLE"
    echo "  スタック: $STACKS"
    echo "  DB: $DB"
    echo "  パッケージマネージャ: $PKG_MANAGER"
    return
  fi
  
  # Q1
  ask "Q1. あなたの名前は？" USER_NAME
  
  # Q2
  ask "Q2. 会社名は？" COMPANY_NAME
  
  # Q3
  ask_choice "Q3. あなたの役割は？" ROLE \
    "経営者 兼 エンジニア（ソロ開発）|solo" \
    "テックリード（チームあり）|lead" \
    "エンジニア（メンバー）|member" \
    "非エンジニア（AI活用したい）|non-eng"
  
  # Q4
  ask_multi "Q4. メインの技術スタックは？" STACKS \
    "Next.js / React|nextjs" \
    "React Native / Expo|react-native" \
    "Vue / Nuxt|vue" \
    "Python / FastAPI / Django|python" \
    "Ruby on Rails|rails" \
    "Go|go" \
    "Swift / iOS|swift" \
    "Flutter|flutter" \
    "その他|other"
  
  # Q5
  ask_choice "Q5. バックエンド/DBは？" DB \
    "Supabase|supabase" \
    "Firebase|firebase" \
    "AWS (RDS, DynamoDB等)|aws" \
    "PlanetScale / MySQL|mysql" \
    "PostgreSQL（自前）|postgres" \
    "その他|other"
  
  # Q6
  ask_choice "Q6. パッケージマネージャは？" PKG_MANAGER \
    "pnpm（推奨）|pnpm" \
    "npm|npm" \
    "yarn|yarn" \
    "bun|bun"
  
  # Q7
  ask_choice "Q7. Codex（Anthropic）は使う予定ある？" USE_CODEX \
    "はい|yes" \
    "いいえ|no" \
    "わからない|no"
  
  # Q8
  ask_choice "Q8. AIエージェントのチーム運用に興味ある？" USE_TEAM \
    "はい、使いたい|yes" \
    "まだ早い、シンプルに使いたい|no"
  
  # Save config
  save_config
  
  echo ""
  info "ヒアリング完了"
}

# ============================================================
# Phase 2: Generate
# ============================================================

# --- Remote Template Download ---
download_templates() {
  echo "テンプレートをダウンロード中..."
  local files=(
    "templates/settings.json.base"
    "templates/claude-md/header.md"
    "templates/claude-md/base-rules.md"
    "templates/claude-md/verification.md"
    "templates/claude-md/stack-nextjs.md"
    "templates/claude-md/stack-react-native.md"
    "templates/claude-md/stack-vue.md"
    "templates/claude-md/stack-python.md"
    "templates/claude-md/stack-rails.md"
    "templates/claude-md/stack-go.md"
    "templates/claude-md/stack-swift.md"
    "templates/claude-md/stack-flutter.md"
    "templates/claude-md/db-supabase.md"
    "templates/claude-md/db-firebase.md"
    "templates/claude-md/db-postgres.md"
    "templates/claude-md/workflow-solo.md"
    "templates/claude-md/workflow-lead.md"
    "templates/claude-md/workflow-member.md"
    "templates/claude-md/workflow-non-eng.md"
    "templates/agents/code-reviewer.md"
    "templates/agents/debugger.md"
    "templates/agents/test-writer.md"
    "templates/agents/security-reviewer.md"
    "templates/agents/typescript-reviewer.md"
    "templates/agents/architect.md"
    "templates/rules/dev-workflow.md"
    "templates/rules/agent-team.md"
    "templates/rules/codex.md"
    "templates/hooks/session-start.sh"
    "templates/hooks/block-no-verify.sh"
    "templates/hooks/block-config-edit.sh"
    "templates/hooks/block-unnecessary-docs.sh"
    "templates/hooks/auto-format.sh"
    "templates/hooks/typecheck.sh"
    "templates/hooks/console-log-check.sh"
    "templates/hooks/pre-compact.sh"
    "templates/hooks/stop-console-check.sh"
    "templates/hooks/subagent-quality.sh"
    "templates/examples/pipeline-content.md"
    "templates/examples/pipeline-feature.md"
    "plugins.txt"
    "merge-settings.sh"
  )
  for f in "${files[@]}"; do
    mkdir -p "$SCRIPT_DIR/$(dirname "$f")"
    curl -sL "$REPO_URL/$f" -o "$SCRIPT_DIR/$f" || warn "Failed to download $f"
  done
  info "テンプレートダウンロード完了"
}

# --- CLAUDE.md Generation ---
generate_claude_md() {
  local output="$1"

  # Header with variable substitution
  local role_label role_desc
  case "$ROLE" in
    solo)    role_label="経営者 兼 エンジニア"; role_desc="ソロ開発（Claude Codeがシニアエンジニア役）。提案・指摘は積極的にしろ。黙って従うな。品質重視。" ;;
    lead)    role_label="テックリード"; role_desc="チーム開発。サブエージェントを管理し、品質ゲートで品質を担保する。" ;;
    member)  role_label="エンジニア"; role_desc="チームメンバー。割り当てられたタスクに集中する。" ;;
    non-eng) role_label="AI活用担当"; role_desc="非エンジニア。Claude Codeを使って業務を効率化する。" ;;
  esac

  # Build tech stack list
  local stack_list=""
  IFS=',' read -ra stacks <<< "$STACKS"
  for s in "${stacks[@]}"; do
    case "$s" in
      nextjs) stack_list="$stack_list Next.js / React /" ;;
      react-native) stack_list="$stack_list React Native (Expo) /" ;;
      vue) stack_list="$stack_list Vue / Nuxt /" ;;
      python) stack_list="$stack_list Python /" ;;
      rails) stack_list="$stack_list Ruby on Rails /" ;;
      go) stack_list="$stack_list Go /" ;;
      swift) stack_list="$stack_list Swift / iOS /" ;;
      flutter) stack_list="$stack_list Flutter /" ;;
      other) stack_list="$stack_list その他 /" ;;
    esac
  done
  # Add DB
  case "$DB" in
    supabase) stack_list="$stack_list Supabase /" ;;
    firebase) stack_list="$stack_list Firebase /" ;;
    postgres) stack_list="$stack_list PostgreSQL /" ;;
    aws) stack_list="$stack_list AWS /" ;;
    mysql) stack_list="$stack_list MySQL /" ;;
  esac
  stack_list=$(echo "$stack_list" | sed 's/ \/$//' | sed 's/^ //')

  # Write header
  sed -e "s/{{USER_NAME}}/$USER_NAME/g" \
      -e "s/{{COMPANY_NAME}}/$COMPANY_NAME/g" \
      -e "s/{{ROLE_LABEL}}/$role_label/g" \
      -e "s|{{ROLE_DESCRIPTION}}|$role_desc|g" \
      -e "s|{{TECH_STACK_LIST}}|$stack_list|g" \
      "$TEMPLATE_DIR/claude-md/header.md" > "$output"

  echo "" >> "$output"
  echo "---" >> "$output"
  echo "" >> "$output"

  # Base rules with PKG_MANAGER substitution
  sed "s/{{PKG_MANAGER}}/$PKG_MANAGER/g" "$TEMPLATE_DIR/claude-md/base-rules.md" >> "$output"

  # Stack-specific rules
  for s in "${stacks[@]}"; do
    local stack_file="$TEMPLATE_DIR/claude-md/stack-${s}.md"
    if [ -f "$stack_file" ]; then
      cat "$stack_file" >> "$output"
    fi
  done

  # DB-specific rules
  local db_file="$TEMPLATE_DIR/claude-md/db-${DB}.md"
  if [ -f "$db_file" ]; then
    cat "$db_file" >> "$output"
  fi

  # Workflow
  local wf_file="$TEMPLATE_DIR/claude-md/workflow-${ROLE}.md"
  if [ -f "$wf_file" ]; then
    echo "" >> "$output"
    echo "---" >> "$output"
    cat "$wf_file" >> "$output"
  fi

  # Verification commands
  echo "" >> "$output"
  echo "---" >> "$output"
  echo "" >> "$output"
  generate_verification >> "$output"
}

generate_verification() {
  echo "# 検証コマンド"
  echo ""
  echo "コード変更後は必ず該当する検証を実行しろ:"

  IFS=',' read -ra stacks <<< "$STACKS"
  for s in "${stacks[@]}"; do
    case "$s" in
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
      vue)
        echo "- 型チェック: \`$PKG_MANAGER tsc --noEmit\`"
        echo "- リント: \`$PKG_MANAGER lint\`"
        echo "- テスト: \`$PKG_MANAGER test\`"
        ;;
      python)
        echo "- リント: \`ruff check .\`"
        echo "- 型チェック: \`mypy .\`"
        echo "- テスト: \`pytest\`"
        ;;
      rails)
        echo "- リント: \`bundle exec rubocop\`"
        echo "- テスト: \`bundle exec rspec\`"
        ;;
      go)
        echo "- Vet: \`go vet ./...\`"
        echo "- テスト: \`go test ./...\`"
        echo "- リント: \`golangci-lint run\`"
        ;;
      swift)
        echo "- ビルド: \`swift build\`"
        echo "- テスト: \`swift test\`"
        ;;
      flutter)
        echo "- 解析: \`flutter analyze\`"
        echo "- テスト: \`flutter test\`"
        ;;
    esac
  done

  case "$DB" in
    supabase) echo "- DB: \`npx supabase db lint\`" ;;
  esac
}

# --- settings.json Generation ---
has_typescript_stack() {
  [[ "$STACKS" =~ nextjs|react-native|vue ]]
}

generate_settings_json() {
  local output="$1"
  cp "$TEMPLATE_DIR/settings.json.base" "$output"

  # Remove TypeScript hooks if no TS stack
  if ! has_typescript_stack; then
    jq 'del(.hooks.PostToolUse[] | select(.description | test("TypeScript|Prettier")))' \
      "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"
  fi

  # Remove SubagentStop if no team
  if [ "$USE_TEAM" != "yes" ]; then
    jq 'del(.hooks.SubagentStop)' "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"
  fi
}

# --- Agent/Rules Selection ---
SELECTED_AGENTS=()
SELECTED_RULES=()

select_agents() {
  SELECTED_AGENTS=("code-reviewer.md" "debugger.md" "test-writer.md" "security-reviewer.md")

  if has_typescript_stack; then
    SELECTED_AGENTS+=("typescript-reviewer.md")
  fi

  if [ "$USE_TEAM" = "yes" ]; then
    SELECTED_AGENTS+=("architect.md")
  fi
}

select_rules() {
  SELECTED_RULES=("dev-workflow.md")

  if [ "$USE_TEAM" = "yes" ]; then
    SELECTED_RULES+=("agent-team.md")
  fi

  if [ "$USE_CODEX" = "yes" ]; then
    SELECTED_RULES+=("codex.md")
  fi
}

phase2_generate() {
  header "設定生成"

  # Download templates if running from remote
  if [ "$SOURCE" = "remote" ]; then
    download_templates
  fi

  GENERATED_DIR=$(mktemp -d)

  # Generate CLAUDE.md
  generate_claude_md "$GENERATED_DIR/CLAUDE.md"
  info "CLAUDE.md 生成完了"

  # Generate settings.json
  generate_settings_json "$GENERATED_DIR/settings.json"
  info "settings.json 生成完了"

  # Determine which agents to include
  select_agents
  info "agents ${#SELECTED_AGENTS[@]}体 選択完了"

  # Determine which rules to include
  select_rules
  info "rules ${#SELECTED_RULES[@]}つ 選択完了"

  if [ "$DRY_RUN" = true ]; then
    echo ""
    warn "DRY RUN: 生成された CLAUDE.md:"
    echo "---"
    cat "$GENERATED_DIR/CLAUDE.md"
    echo "---"
  fi
}

# ============================================================
# Phase 3: Install
# ============================================================

# --- Backup ---
backup_existing() {
  local backup_dir="$HOME/.claude/backups"
  mkdir -p "$backup_dir"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  if [ -f "$HOME/.claude/settings.json" ]; then
    cp "$HOME/.claude/settings.json" "$backup_dir/settings.json.$timestamp"
    info "settings.json バックアップ完了"
  fi

  # Keep only last 5 backups
  ls -t "$backup_dir"/settings.json.* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
}

# --- Install CLAUDE.md ---
install_claude_md() {
  if [ -f "$HOME/CLAUDE.md" ]; then
    cp "$GENERATED_DIR/CLAUDE.md" /tmp/claude-kickstart-preview-CLAUDE.md
    echo ""
    echo "既存の ~/CLAUDE.md が見つかりました。"
    echo "差分:"
    diff "$HOME/CLAUDE.md" /tmp/claude-kickstart-preview-CLAUDE.md || true
    echo ""
    echo "  1) 上書き"
    echo "  2) スキップ"
    echo "  3) バックアップして上書き"
    echo -en "選択 [2]: "
    read -r choice
    choice=${choice:-2}
    case "$choice" in
      1) cp "$GENERATED_DIR/CLAUDE.md" "$HOME/CLAUDE.md"; info "~/CLAUDE.md 上書き完了" ;;
      3) cp "$HOME/CLAUDE.md" "$HOME/CLAUDE.md.backup"; cp "$GENERATED_DIR/CLAUDE.md" "$HOME/CLAUDE.md"; info "~/CLAUDE.md バックアップ&上書き完了" ;;
      *) warn "~/CLAUDE.md スキップ" ;;
    esac
  else
    cp "$GENERATED_DIR/CLAUDE.md" "$HOME/CLAUDE.md"
    info "~/CLAUDE.md 生成完了"
  fi
}

# --- Install settings.json ---
install_settings_json() {
  mkdir -p "$HOME/.claude"

  if [ -f "$HOME/.claude/settings.json" ]; then
    # Merge using merge-settings.sh
    local merge_script="$SCRIPT_DIR/merge-settings.sh"
    if [ -f "$merge_script" ]; then
      bash "$merge_script" "$HOME/.claude/settings.json" "$GENERATED_DIR/settings.json" > /tmp/kickstart-merged.json
      mv /tmp/kickstart-merged.json "$HOME/.claude/settings.json"
      info "settings.json マージ完了"
    else
      warn "merge-settings.sh が見つかりません。上書きします"
      cp "$GENERATED_DIR/settings.json" "$HOME/.claude/settings.json"
    fi
  else
    cp "$GENERATED_DIR/settings.json" "$HOME/.claude/settings.json"
    info "settings.json 生成完了"
  fi
}

# --- Install Agents ---
install_agents() {
  mkdir -p "$HOME/.claude/agents"
  local count=0
  for agent in "${SELECTED_AGENTS[@]}"; do
    if [ -f "$HOME/.claude/agents/$agent" ]; then
      echo -en "  $agent は既に存在します。上書きしますか？ (y/N): "
      read -r overwrite
      if [[ ! "$overwrite" =~ ^[Yy] ]]; then
        continue
      fi
    fi
    cp "$TEMPLATE_DIR/agents/$agent" "$HOME/.claude/agents/$agent"
    ((count++))
  done
  info "agents ${count}体 配置完了"
}

# --- Install Rules ---
install_rules() {
  mkdir -p "$HOME/.claude/rules"
  local count=0
  for rule in "${SELECTED_RULES[@]}"; do
    if [ -f "$HOME/.claude/rules/$rule" ]; then
      echo -en "  $rule は既に存在します。上書きしますか？ (y/N): "
      read -r overwrite
      if [[ ! "$overwrite" =~ ^[Yy] ]]; then
        continue
      fi
    fi
    cp "$TEMPLATE_DIR/rules/$rule" "$HOME/.claude/rules/$rule"
    ((count++))
  done
  info "rules ${count}つ 配置完了"
}

# --- Install Hooks ---
install_hooks() {
  mkdir -p "$HOME/.claude/hooks"
  for hook in "$TEMPLATE_DIR"/hooks/*.sh; do
    local basename
    basename=$(basename "$hook")
    cp "$hook" "$HOME/.claude/hooks/$basename"
    chmod +x "$HOME/.claude/hooks/$basename"
  done
  info "hooks 配置完了"
}

# --- Install Examples ---
install_examples() {
  mkdir -p "$HOME/.claude/examples"
  for example in "$TEMPLATE_DIR"/examples/*.md; do
    local basename
    basename=$(basename "$example")
    cp "$example" "$HOME/.claude/examples/$basename"
  done
  info "examples 配置完了"
}

# --- Install Plugins ---
install_plugins() {
  echo ""
  echo -e "${BOLD}プラグインインストール...${NC}"
  local plugins_file="$SCRIPT_DIR/plugins.txt"
  if [ ! -f "$plugins_file" ]; then
    warn "plugins.txt が見つかりません。スキップ"
    return
  fi
  while IFS= read -r plugin || [ -n "$plugin" ]; do
    [ -z "$plugin" ] && continue
    echo -e "  ${BLUE}→${NC} $plugin"
    claude plugin add "$plugin" 2>/dev/null && info "$plugin" || warn "$plugin (スキップ)"
  done < "$plugins_file"
}

# --- Install AgentShield ---
install_agentshield() {
  echo ""
  if npm list -g ecc-agentshield >/dev/null 2>&1; then
    info "AgentShield 既にインストール済み"
  else
    echo -e "  ${BLUE}→${NC} AgentShield インストール中..."
    npm install -g ecc-agentshield 2>/dev/null && info "AgentShield インストール完了" || warn "AgentShield インストールスキップ"
  fi

  # Run security scan
  if command -v npx >/dev/null 2>&1; then
    echo ""
    echo -e "${BOLD}セキュリティスキャン...${NC}"
    npx ecc-agentshield scan --path "$HOME/.claude" 2>&1 | grep -E "^  Grade:" | head -1 || warn "スキャンスキップ"
  fi
}

phase3_install() {
  header "インストール"

  if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN: ファイルは書き込まれません"
    echo "  生成される agents: ${SELECTED_AGENTS[*]}"
    echo "  生成される rules: ${SELECTED_RULES[*]}"
    return
  fi

  # Backup
  backup_existing

  # Install CLAUDE.md
  install_claude_md

  # Install settings.json
  install_settings_json

  # Install agents
  install_agents

  # Install rules
  install_rules

  # Install hooks
  install_hooks

  # Install examples (only for team users)
  if [ "$USE_TEAM" = "yes" ]; then
    install_examples
  fi

  # Install plugins
  install_plugins

  # Install AgentShield
  install_agentshield
}

# ============================================================
# Phase 4: Summary (placeholder)
# ============================================================

phase4_summary() {
  header "セットアップ完了"
  warn "Phase 4: 未実装 — 次のタスクで追加"
}

# ============================================================
# Main
# ============================================================

main() {
  # Handle rollback
  if [ "$ROLLBACK" = true ]; then
    handle_rollback
  fi
  
  # Phase 0
  phase0_prerequisites
  
  # Phase 1
  phase1_interview
  
  # Phase 2
  phase2_generate
  
  # Phase 3
  phase3_install
  
  # Phase 4
  phase4_summary
}

main "$@"
