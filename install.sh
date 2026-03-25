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
# Phase 2: Generate (placeholder)
# ============================================================

phase2_generate() {
  header "設定生成"
  warn "Phase 2: 未実装 — 次のタスクで追加"
}

# ============================================================
# Phase 3: Install (placeholder)
# ============================================================

phase3_install() {
  header "インストール"
  warn "Phase 3: 未実装 — 次のタスクで追加"
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
