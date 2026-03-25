const readline = require('readline');
const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

// --- Colors ---
const colors = {
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  green: (s) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s) => `\x1b[33m${s}\x1b[0m`,
  blue: (s) => `\x1b[34m${s}\x1b[0m`,
  bold: (s) => `\x1b[1m${s}\x1b[0m`,
};

const info = (msg) => console.log(`  ${colors.green('✓')} ${msg}`);
const warn = (msg) => console.log(`  ${colors.yellow('!')} ${msg}`);
const error = (msg) => console.log(`  ${colors.red('✗')} ${msg}`);
const header = (msg) => console.log(`\n${colors.bold(colors.blue(`=== ${msg} ===`))}\n`);

// --- Readline helper ---
function createRL() {
  return readline.createInterface({ input: process.stdin, output: process.stdout });
}

function ask(rl, prompt, defaultVal) {
  return new Promise((resolve) => {
    const suffix = defaultVal ? ` [${defaultVal}]` : '';
    rl.question(`${colors.bold(prompt)}${suffix}: `, (answer) => {
      resolve(answer.trim() || defaultVal || '');
    });
  });
}

function askChoice(rl, prompt, options) {
  return new Promise((resolve) => {
    console.log(`\n${colors.bold(prompt)}`);
    options.forEach((opt, i) => {
      console.log(`  ${i + 1}) ${opt.label}`);
    });
    rl.question('選択 [1]: ', (answer) => {
      const idx = parseInt(answer || '1', 10) - 1;
      resolve(options[Math.min(Math.max(idx, 0), options.length - 1)].value);
    });
  });
}

function askMulti(rl, prompt, options) {
  return new Promise((resolve) => {
    console.log(`\n${colors.bold(prompt)}（複数選択可、カンマ区切り）`);
    options.forEach((opt, i) => {
      console.log(`  ${i + 1}) ${opt.label}`);
    });
    rl.question('選択 [1]: ', (answer) => {
      const indices = (answer || '1').split(',').map(s => parseInt(s.trim(), 10) - 1);
      const values = indices
        .filter(i => i >= 0 && i < options.length)
        .map(i => options[i].value);
      resolve(values.length > 0 ? values.join(',') : options[0].value);
    });
  });
}

// --- Command helpers ---
function commandExists(cmd) {
  try {
    if (process.platform === 'win32') {
      execSync(`where ${cmd}`, { stdio: 'ignore' });
    } else {
      execSync(`which ${cmd}`, { stdio: 'ignore' });
    }
    return true;
  } catch { return false; }
}

function runCommand(cmd, options = {}) {
  try {
    return execSync(cmd, { encoding: 'utf-8', stdio: options.stdio || 'pipe', ...options }).trim();
  } catch (e) {
    return options.fallback || '';
  }
}

function getHomeDir() {
  return os.homedir();
}

function getClaudeDir() {
  return path.join(getHomeDir(), '.claude');
}

// --- Template directory ---
function getTemplateDir() {
  // Check if templates exist locally (cloned repo)
  const localDir = path.join(__dirname, '..', 'templates');
  if (fs.existsSync(path.join(localDir, 'settings.json.base'))) {
    return localDir;
  }
  // For npx, templates are in the package
  return localDir;
}

// ============================================================
// Phase 0: Prerequisites
// ============================================================

async function phase0(rl, flags) {
  header(`claude-kickstart v1.0.0`);
  console.log('Claude Code環境を最適な状態にセットアップします。');

  if (flags.dryRun) {
    warn('DRY RUN モード — ファイルは書き込まれません');
  }

  console.log('');
  console.log(colors.bold('[前提チェック中...]'));

  const platform = process.platform; // 'win32', 'darwin', 'linux'

  // Node.js (already running, so just check version)
  const nodeVersion = process.version;
  const major = parseInt(nodeVersion.slice(1).split('.')[0], 10);
  if (major >= 18) {
    info(`Node.js ${nodeVersion}`);
  } else {
    error(`Node.js ${nodeVersion} — v18以上が必要です`);
    process.exit(1);
  }

  // Git
  if (commandExists('git')) {
    const gitVersion = runCommand('git --version');
    info(`Git ${gitVersion.replace('git version ', '')}`);
  } else {
    error('Git が見つかりません');
    if (platform === 'win32') {
      console.log('  → https://git-scm.com/download/win からインストール');
    } else if (platform === 'darwin') {
      console.log('  → xcode-select --install');
    } else {
      console.log('  → sudo apt install -y git');
    }
    process.exit(1);
  }

  // Claude Code
  if (commandExists('claude')) {
    const claudeVersion = runCommand('claude --version', { fallback: 'installed' });
    info(`Claude Code ${claudeVersion}`);
  } else {
    error('Claude Code が見つかりません');
    const answer = await ask(rl, 'インストールしますか？ (Y/n)', 'Y');
    if (answer.toLowerCase() === 'n') {
      process.exit(1);
    }
    console.log('  Claude Code をインストール中...');
    try {
      execSync('npm install -g @anthropic-ai/claude-code', { stdio: 'inherit' });
      info('Claude Code インストール完了');
    } catch {
      error('Claude Codeのインストールに失敗');
      process.exit(1);
    }
  }

  // jq (optional on Windows - we use Node.js for JSON)
  if (platform !== 'win32') {
    if (commandExists('jq')) {
      info('jq available');
    } else {
      warn('jq が見つかりません（Node.js版では不要）');
    }
  }

  console.log('');
  info('前提チェック完了');
}

// ============================================================
// Phase 0.5: Rollback
// ============================================================

function handleRollback(rl) {
  header('ロールバック');
  const backupDir = path.join(getClaudeDir(), 'backups');

  if (!fs.existsSync(backupDir)) {
    error('バックアップが見つかりません');
    process.exit(1);
  }

  const backups = fs.readdirSync(backupDir)
    .filter(f => f.startsWith('settings.json.'))
    .sort()
    .reverse();

  if (backups.length === 0) {
    error('バックアップが見つかりません');
    process.exit(1);
  }

  const latest = path.join(backupDir, backups[0]);
  console.log(`復元元: ${latest}`);

  return ask(rl, '復元しますか？ (Y/n)', 'Y').then(answer => {
    if (answer.toLowerCase() === 'n') {
      console.log('キャンセルしました');
      process.exit(0);
    }
    fs.copyFileSync(latest, path.join(getClaudeDir(), 'settings.json'));
    info('settings.json を復元しました');
    process.exit(0);
  });
}

// ============================================================
// Phase 1: Interview
// ============================================================

function getConfigPath() {
  return path.join(getClaudeDir(), 'kickstart-config.json');
}

function loadConfig() {
  const configPath = getConfigPath();
  if (fs.existsSync(configPath)) {
    try {
      return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
    } catch { return null; }
  }
  return null;
}

function saveConfig(config) {
  const configPath = getConfigPath();
  fs.mkdirSync(path.dirname(configPath), { recursive: true });
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}

async function phase1(rl, flags) {
  header('セットアップ');

  // Try loading existing config
  if (!flags.reconfigure) {
    const existing = loadConfig();
    if (existing) {
      console.log('');
      console.log(`前回の設定が見つかりました: ${colors.blue(getConfigPath())}`);
      const useExisting = await ask(rl, '前回の設定を使いますか？ (Y/n)', 'Y');
      if (useExisting.toLowerCase() !== 'n') {
        info('前回の設定を読み込みました');
        console.log(`  名前: ${existing.name}`);
        console.log(`  会社: ${existing.company}`);
        console.log(`  役割: ${existing.role}`);
        console.log(`  スタック: ${existing.stacks}`);
        console.log(`  DB: ${existing.db}`);
        console.log(`  パッケージマネージャ: ${existing.pkg_manager}`);
        return existing;
      }
    }
  }

  const config = {};

  // Q1
  config.name = await ask(rl, 'Q1. あなたの名前は？');

  // Q2
  config.company = await ask(rl, 'Q2. 会社名は？');

  // Q3
  config.role = await askChoice(rl, 'Q3. あなたの役割は？', [
    { label: '経営者 兼 エンジニア（ソロ開発）', value: 'solo' },
    { label: 'テックリード（チームあり）', value: 'lead' },
    { label: 'エンジニア（メンバー）', value: 'member' },
    { label: '非エンジニア（AI活用したい）', value: 'non-eng' },
  ]);

  // Q4
  config.stacks = await askMulti(rl, 'Q4. メインの技術スタックは？', [
    { label: 'Next.js / React', value: 'nextjs' },
    { label: 'React Native / Expo', value: 'react-native' },
    { label: 'Vue / Nuxt', value: 'vue' },
    { label: 'Python / FastAPI / Django', value: 'python' },
    { label: 'Ruby on Rails', value: 'rails' },
    { label: 'Go', value: 'go' },
    { label: 'Swift / iOS', value: 'swift' },
    { label: 'Flutter', value: 'flutter' },
    { label: 'その他', value: 'other' },
  ]);

  // Q5
  config.db = await askChoice(rl, 'Q5. バックエンド/DBは？', [
    { label: 'Supabase', value: 'supabase' },
    { label: 'Firebase', value: 'firebase' },
    { label: 'AWS (RDS, DynamoDB等)', value: 'aws' },
    { label: 'PlanetScale / MySQL', value: 'mysql' },
    { label: 'PostgreSQL（自前）', value: 'postgres' },
    { label: 'その他', value: 'other' },
  ]);

  // Q6
  config.pkg_manager = await askChoice(rl, 'Q6. パッケージマネージャは？', [
    { label: 'pnpm（推奨）', value: 'pnpm' },
    { label: 'npm', value: 'npm' },
    { label: 'yarn', value: 'yarn' },
    { label: 'bun', value: 'bun' },
  ]);

  // Q7
  config.use_codex = await askChoice(rl, 'Q7. Codex（Anthropic）は使う予定ある？', [
    { label: 'はい', value: 'yes' },
    { label: 'いいえ', value: 'no' },
    { label: 'わからない', value: 'no' },
  ]);

  // Q8
  config.use_team = await askChoice(rl, 'Q8. AIエージェントのチーム運用に興味ある？', [
    { label: 'はい、使いたい', value: 'yes' },
    { label: 'まだ早い、シンプルに使いたい', value: 'no' },
  ]);

  // Save
  saveConfig(config);
  console.log('');
  info('ヒアリング完了');

  return config;
}

// ============================================================
// Phase 2: Generate
// ============================================================

function hasTypescriptStack(stacks) {
  return stacks.split(',').some(s => ['nextjs', 'react-native', 'vue'].includes(s));
}

function getRoleLabel(role) {
  const map = { solo: '経営者 兼 エンジニア', lead: 'テックリード', member: 'エンジニア', 'non-eng': 'AI活用担当' };
  return map[role] || role;
}

function getRoleDesc(role) {
  const map = {
    solo: 'ソロ開発（Claude Codeがシニアエンジニア役）。提案・指摘は積極的にしろ。黙って従うな。品質重視。',
    lead: 'チーム開発。サブエージェントを管理し、品質ゲートで品質を担保する。',
    member: 'チームメンバー。割り当てられたタスクに集中する。',
    'non-eng': '非エンジニア。Claude Codeを使って業務を効率化する。',
  };
  return map[role] || '';
}

function getStackDisplay(stack) {
  const map = { nextjs: 'Next.js / React', 'react-native': 'React Native (Expo)', vue: 'Vue / Nuxt', python: 'Python', rails: 'Ruby on Rails', go: 'Go', swift: 'Swift / iOS', flutter: 'Flutter', other: 'その他' };
  return map[stack] || stack;
}

function getDbDisplay(db) {
  const map = { supabase: 'Supabase', firebase: 'Firebase', postgres: 'PostgreSQL', aws: 'AWS', mysql: 'MySQL', other: 'その他' };
  return map[db] || db;
}

function generateClaudeMd(config, templateDir) {
  const stacks = config.stacks.split(',');
  let content = '';

  // Header
  let headerTpl = fs.readFileSync(path.join(templateDir, 'claude-md', 'header.md'), 'utf-8');
  const stackList = stacks.map(s => getStackDisplay(s)).join(' / ') + ' / ' + getDbDisplay(config.db);
  headerTpl = headerTpl
    .replace(/\{\{USER_NAME\}\}/g, config.name)
    .replace(/\{\{COMPANY_NAME\}\}/g, config.company)
    .replace(/\{\{ROLE_LABEL\}\}/g, getRoleLabel(config.role))
    .replace(/\{\{ROLE_DESCRIPTION\}\}/g, getRoleDesc(config.role))
    .replace(/\{\{TECH_STACK_LIST\}\}/g, stackList);
  content += headerTpl + '\n\n---\n\n';

  // Base rules
  let baseRules = fs.readFileSync(path.join(templateDir, 'claude-md', 'base-rules.md'), 'utf-8');
  baseRules = baseRules.replace(/\{\{PKG_MANAGER\}\}/g, config.pkg_manager);
  content += baseRules + '\n';

  // Stack rules
  for (const s of stacks) {
    const stackFile = path.join(templateDir, 'claude-md', `stack-${s}.md`);
    if (fs.existsSync(stackFile)) {
      content += fs.readFileSync(stackFile, 'utf-8') + '\n';
    }
  }

  // DB rules
  const dbFile = path.join(templateDir, 'claude-md', `db-${config.db}.md`);
  if (fs.existsSync(dbFile)) {
    content += fs.readFileSync(dbFile, 'utf-8') + '\n';
  }

  // Workflow
  const wfFile = path.join(templateDir, 'claude-md', `workflow-${config.role}.md`);
  if (fs.existsSync(wfFile)) {
    content += '\n---\n' + fs.readFileSync(wfFile, 'utf-8') + '\n';
  }

  // Verification
  content += '\n---\n\n';
  content += generateVerification(config);

  return content;
}

function generateVerification(config) {
  const stacks = config.stacks.split(',');
  const pkg = config.pkg_manager;
  let lines = ['# 検証コマンド', '', 'コード変更後は必ず該当する検証を実行しろ:'];

  for (const s of stacks) {
    switch (s) {
      case 'nextjs':
        lines.push(`- 型チェック: \`${pkg} tsc --noEmit\``, `- リント: \`${pkg} lint\``, `- テスト: \`${pkg} test\``, `- ビルド: \`${pkg} build\``);
        break;
      case 'react-native':
        lines.push(`- 型チェック: \`${pkg} tsc --noEmit\``, `- リント: \`${pkg} lint\``, `- Expo: \`npx expo doctor\``);
        break;
      case 'vue':
        lines.push(`- 型チェック: \`${pkg} tsc --noEmit\``, `- リント: \`${pkg} lint\``, `- テスト: \`${pkg} test\``);
        break;
      case 'python':
        lines.push('- リント: `ruff check .`', '- 型チェック: `mypy .`', '- テスト: `pytest`');
        break;
      case 'rails':
        lines.push('- リント: `bundle exec rubocop`', '- テスト: `bundle exec rspec`');
        break;
      case 'go':
        lines.push('- Vet: `go vet ./...`', '- テスト: `go test ./...`', '- リント: `golangci-lint run`');
        break;
      case 'swift':
        lines.push('- ビルド: `swift build`', '- テスト: `swift test`');
        break;
      case 'flutter':
        lines.push('- 解析: `flutter analyze`', '- テスト: `flutter test`');
        break;
    }
  }

  if (config.db === 'supabase') {
    lines.push('- DB: `npx supabase db lint`');
  }

  return lines.join('\n') + '\n';
}

function generateSettingsJson(config, templateDir) {
  const base = JSON.parse(fs.readFileSync(path.join(templateDir, 'settings.json.base'), 'utf-8'));

  // Remove TypeScript hooks if no TS stack
  if (!hasTypescriptStack(config.stacks)) {
    if (base.hooks && base.hooks.PostToolUse) {
      base.hooks.PostToolUse = base.hooks.PostToolUse.filter(h =>
        !h.description || (!h.description.includes('TypeScript') && !h.description.includes('Prettier'))
      );
    }
  }

  // Remove SubagentStop if no team
  if (config.use_team !== 'yes') {
    delete base.hooks.SubagentStop;
  }

  return base;
}

function selectAgents(config) {
  const agents = ['code-reviewer.md', 'debugger.md', 'test-writer.md', 'security-reviewer.md'];
  if (hasTypescriptStack(config.stacks)) agents.push('typescript-reviewer.md');
  if (config.use_team === 'yes') agents.push('architect.md');
  return agents;
}

function selectRules(config) {
  const rules = ['dev-workflow.md'];
  if (config.use_team === 'yes') rules.push('agent-team.md');
  if (config.use_codex === 'yes') rules.push('codex.md');
  return rules;
}

function phase2(config, flags) {
  header('設定生成');

  const templateDir = getTemplateDir();

  const claudeMd = generateClaudeMd(config, templateDir);
  info('CLAUDE.md 生成完了');

  const settingsJson = generateSettingsJson(config, templateDir);
  info('settings.json 生成完了');

  const agents = selectAgents(config);
  info(`agents ${agents.length}体 選択完了`);

  const rules = selectRules(config);
  info(`rules ${rules.length}つ 選択完了`);

  if (flags.dryRun) {
    console.log('');
    warn('DRY RUN: 生成される CLAUDE.md:');
    console.log('---');
    console.log(claudeMd);
    console.log('---');
  }

  return { claudeMd, settingsJson, agents, rules, templateDir };
}

// ============================================================
// Phase 3: Install
// ============================================================

function mergeSettingsJson(existing, newSettings) {
  // Merge permissions.allow
  const allowSet = new Set([
    ...(existing.permissions?.allow || []),
    ...(newSettings.permissions?.allow || []),
  ]);

  // Merge permissions.deny
  const denySet = new Set([
    ...(existing.permissions?.deny || []),
    ...(newSettings.permissions?.deny || []),
  ]);

  // Merge hooks
  const mergedHooks = {};
  const allHookKeys = new Set([
    ...Object.keys(existing.hooks || {}),
    ...Object.keys(newSettings.hooks || {}),
  ]);

  for (const key of allHookKeys) {
    const existingHooks = (existing.hooks || {})[key] || [];
    const newHooks = (newSettings.hooks || {})[key] || [];
    const combined = [...existingHooks, ...newHooks];

    // Dedupe by description
    const seen = new Set();
    mergedHooks[key] = combined.filter(h => {
      const id = h.description || h.matcher || JSON.stringify(h);
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    });
  }

  // Build result: keep existing fields, merge permissions and hooks
  const result = { ...existing };
  result.permissions = {
    ...existing.permissions,
    allow: [...allowSet],
    deny: [...denySet],
  };
  result.hooks = mergedHooks;

  return result;
}

function backup(claudeDir) {
  const backupDir = path.join(claudeDir, 'backups');
  fs.mkdirSync(backupDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 15);

  const settingsPath = path.join(claudeDir, 'settings.json');
  if (fs.existsSync(settingsPath)) {
    fs.copyFileSync(settingsPath, path.join(backupDir, `settings.json.${timestamp}`));
    info('settings.json バックアップ完了');
  }

  // Keep only last 5
  const backups = fs.readdirSync(backupDir)
    .filter(f => f.startsWith('settings.json.'))
    .sort()
    .reverse();
  for (const old of backups.slice(5)) {
    fs.unlinkSync(path.join(backupDir, old));
  }
}

async function phase3(rl, config, generated, flags) {
  header('インストール');

  if (flags.dryRun) {
    warn('DRY RUN: ファイルは書き込まれません');
    console.log(`  生成される agents: ${generated.agents.join(', ')}`);
    console.log(`  生成される rules: ${generated.rules.join(', ')}`);
    return;
  }

  const homeDir = getHomeDir();
  const claudeDir = getClaudeDir();

  // Backup
  backup(claudeDir);

  // Install CLAUDE.md
  const claudeMdPath = path.join(homeDir, 'CLAUDE.md');
  if (fs.existsSync(claudeMdPath)) {
    console.log('');
    console.log('既存の ~/CLAUDE.md が見つかりました。');
    const choice = await askChoice(rl, 'どうしますか？', [
      { label: 'スキップ', value: 'skip' },
      { label: '上書き', value: 'overwrite' },
      { label: 'バックアップして上書き', value: 'backup' },
    ]);
    if (choice === 'overwrite') {
      fs.writeFileSync(claudeMdPath, generated.claudeMd);
      info('~/CLAUDE.md 上書き完了');
    } else if (choice === 'backup') {
      fs.copyFileSync(claudeMdPath, claudeMdPath + '.backup');
      fs.writeFileSync(claudeMdPath, generated.claudeMd);
      info('~/CLAUDE.md バックアップ&上書き完了');
    } else {
      warn('~/CLAUDE.md スキップ');
    }
  } else {
    fs.writeFileSync(claudeMdPath, generated.claudeMd);
    info('~/CLAUDE.md 生成完了');
  }

  // Install settings.json
  const settingsPath = path.join(claudeDir, 'settings.json');
  fs.mkdirSync(claudeDir, { recursive: true });
  if (fs.existsSync(settingsPath)) {
    const existing = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
    const merged = mergeSettingsJson(existing, generated.settingsJson);
    fs.writeFileSync(settingsPath, JSON.stringify(merged, null, 2));
    info('settings.json マージ完了');
  } else {
    fs.writeFileSync(settingsPath, JSON.stringify(generated.settingsJson, null, 2));
    info('settings.json 生成完了');
  }

  // Install agents
  const agentsDir = path.join(claudeDir, 'agents');
  fs.mkdirSync(agentsDir, { recursive: true });
  let agentCount = 0;
  for (const agent of generated.agents) {
    const dest = path.join(agentsDir, agent);
    const src = path.join(generated.templateDir, 'agents', agent);
    if (fs.existsSync(dest)) {
      const ow = await ask(rl, `  ${agent} は既に存在します。上書きしますか？ (y/N)`, 'N');
      if (ow.toLowerCase() !== 'y') continue;
    }
    fs.copyFileSync(src, dest);
    agentCount++;
  }
  info(`agents ${agentCount}体 配置完了`);

  // Install rules
  const rulesDir = path.join(claudeDir, 'rules');
  fs.mkdirSync(rulesDir, { recursive: true });
  let ruleCount = 0;
  for (const rule of generated.rules) {
    const dest = path.join(rulesDir, rule);
    const src = path.join(generated.templateDir, 'rules', rule);
    if (fs.existsSync(dest)) {
      const ow = await ask(rl, `  ${rule} は既に存在します。上書きしますか？ (y/N)`, 'N');
      if (ow.toLowerCase() !== 'y') continue;
    }
    fs.copyFileSync(src, dest);
    ruleCount++;
  }
  info(`rules ${ruleCount}つ 配置完了`);

  // Install hooks
  const hooksDir = path.join(claudeDir, 'hooks');
  fs.mkdirSync(hooksDir, { recursive: true });
  const hooksSrcDir = path.join(generated.templateDir, 'hooks');
  if (fs.existsSync(hooksSrcDir)) {
    for (const file of fs.readdirSync(hooksSrcDir)) {
      if (file.endsWith('.sh')) {
        const dest = path.join(hooksDir, file);
        fs.copyFileSync(path.join(hooksSrcDir, file), dest);
        if (process.platform !== 'win32') {
          fs.chmodSync(dest, 0o755);
        }
      }
    }
    info('hooks 配置完了');
  }

  // Install examples (team only)
  if (config.use_team === 'yes') {
    const examplesDir = path.join(claudeDir, 'examples');
    fs.mkdirSync(examplesDir, { recursive: true });
    const exSrcDir = path.join(generated.templateDir, 'examples');
    if (fs.existsSync(exSrcDir)) {
      for (const file of fs.readdirSync(exSrcDir)) {
        fs.copyFileSync(path.join(exSrcDir, file), path.join(examplesDir, file));
      }
      info('examples 配置完了');
    }
  }

  // Install plugins
  console.log('');
  console.log(colors.bold('プラグインインストール...'));
  const pluginsFile = path.join(generated.templateDir, '..', 'plugins.txt');
  if (fs.existsSync(pluginsFile)) {
    const plugins = fs.readFileSync(pluginsFile, 'utf-8').trim().split('\n').filter(Boolean);
    for (const plugin of plugins) {
      console.log(`  ${colors.blue('→')} ${plugin}`);
      try {
        execSync(`claude plugin add ${plugin}`, { stdio: 'ignore', timeout: 30000 });
        info(plugin);
      } catch {
        warn(`${plugin} (スキップ)`);
      }
    }
  }

  // Install AgentShield
  console.log('');
  try {
    execSync('npm list -g ecc-agentshield', { stdio: 'ignore' });
    info('AgentShield 既にインストール済み');
  } catch {
    console.log(`  ${colors.blue('→')} AgentShield インストール中...`);
    try {
      execSync('npm install -g ecc-agentshield', { stdio: 'ignore', timeout: 60000 });
      info('AgentShield インストール完了');
    } catch {
      warn('AgentShield インストールスキップ');
    }
  }
}

// ============================================================
// Phase 4: Summary
// ============================================================

function phase4(config, generated) {
  header('セットアップ完了');

  const roleDisplay = { solo: '経営者 兼 エンジニア（ソロ開発）', lead: 'テックリード（チームあり）', member: 'エンジニア（メンバー）', 'non-eng': '非エンジニア（AI活用）' };

  console.log(colors.bold('あなたの環境:'));
  console.log(`  名前: ${config.name}`);
  console.log(`  会社: ${config.company}`);
  console.log(`  役割: ${roleDisplay[config.role] || config.role}`);
  console.log(`  スタック: ${config.stacks.split(',').map(s => getStackDisplay(s)).join(', ')}`);
  console.log(`  DB: ${getDbDisplay(config.db)}`);
  console.log(`  パッケージマネージャ: ${config.pkg_manager}`);

  console.log('');
  console.log(colors.bold('生成されたファイル:'));
  console.log('  ~/CLAUDE.md              ← プロジェクト共通ルール');
  console.log('  ~/.claude/settings.json  ← hooks, permissions, deny list');
  console.log(`  ~/.claude/agents/        ← AIエージェント定義 (${generated.agents.length}体)`);
  console.log(`  ~/.claude/rules/         ← ワークフロールール (${generated.rules.length}つ)`);
  console.log('  ~/.claude/hooks/         ← 自動化hookスクリプト');
  if (config.use_team === 'yes') {
    console.log('  ~/.claude/examples/      ← パイプラインパターン例');
  }

  console.log('');
  console.log(colors.bold('次のステップ:'));
  console.log('  1. ~/CLAUDE.md を開いて内容を確認・調整してください');
  console.log(`  2. プロジェクトディレクトリに移動して ${colors.blue('claude')} と起動`);
  console.log('  3. 「何か聞いてみて」ください');

  if (config.stacks.includes('other')) {
    console.log('');
    warn('「その他」のスタックを選択しました。~/CLAUDE.md にスタック固有のルールを手動で追加してください');
  }
  if (config.db === 'other') {
    warn('「その他」のDBを選択しました。~/CLAUDE.md にDB固有のルールを手動で追加してください');
  }

  console.log('');
  console.log(colors.bold('ドキュメント:'));
  console.log('  https://github.com/cradle-team/claude-kickstart');
  console.log('');
}

// ============================================================
// Main
// ============================================================

async function main() {
  const args = process.argv.slice(2);
  const flags = {
    dryRun: args.includes('--dry-run'),
    rollback: args.includes('--rollback'),
    reconfigure: args.includes('--reconfigure'),
  };

  if (args.includes('--version')) {
    console.log('claude-kickstart v1.0.0');
    return;
  }

  if (args.includes('--help')) {
    console.log('Usage: npx claude-kickstart [OPTIONS]');
    console.log('');
    console.log('Options:');
    console.log('  --dry-run       プレビューモード（ファイルを書き込まない）');
    console.log('  --rollback      直前のバックアップに復元');
    console.log('  --reconfigure   ヒアリングをやり直す');
    console.log('  --version       バージョン表示');
    console.log('  --help          このヘルプを表示');
    return;
  }

  const rl = createRL();

  try {
    if (flags.rollback) {
      await handleRollback(rl);
      return;
    }

    await phase0(rl, flags);
    const config = await phase1(rl, flags);
    const generated = phase2(config, flags);
    await phase3(rl, config, generated, flags);
    phase4(config, generated);
  } finally {
    rl.close();
  }
}

module.exports = { main };
