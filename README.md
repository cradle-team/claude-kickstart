# claude-kickstart

Claude Code環境を対話式ヒアリングでパーソナライズし、ワンライナーでセットアップするインストーラー。

中小スタートアップ向け。「これ入れて」の一言で、最適化されたAIエージェント開発環境が完成する。

## インストール（コマンド一発）

何も入ってない状態から、コマンド一発でClaude Code環境が完成する。

### Windows（PowerShell）

```powershell
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements; refreshenv; npx claude-kickstart
```

### Mac

```bash
brew install node; npx claude-kickstart
```

> Homebrew未インストールの場合は先に: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Linux（Ubuntu/Debian）

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install -y nodejs && npx claude-kickstart
```

### Node.jsが既に入っている場合

```
npx claude-kickstart
```

これだけ。Windows/Mac/Linux全対応。

### その他の実行方法

<details>
<summary>bash版（Mac/Linux）</summary>

```bash
curl -sL https://raw.githubusercontent.com/cradle-team/claude-kickstart/main/install.sh | bash
```
</details>

<details>
<summary>ローカルから実行</summary>

```bash
git clone https://github.com/cradle-team/claude-kickstart.git
cd claude-kickstart
bash install.sh
```
</details>

## 何がインストールされるか

| カテゴリ | 内容 |
|---------|------|
| `~/CLAUDE.md` | プロジェクト共通ルール（スタック・DB・ロール別にカスタマイズ） |
| `~/.claude/settings.json` | hooks, permissions, deny list（既存設定とマージ） |
| `~/.claude/agents/` | AIエージェント定義（4-6体、スタックに応じて選択） |
| `~/.claude/rules/` | ワークフロールール（1-3ファイル、チーム運用に応じて選択） |
| `~/.claude/hooks/` | 自動化hookスクリプト（10個） |
| プラグイン | superpowers, pr-review-toolkit, frontend-design, code-simplifier |
| AgentShield | Claude Code設定のセキュリティスキャナー |

## ヒアリングの流れ

インストーラーは8つの質問であなたの環境を把握し、最適な設定を生成する。

1. **名前** — CLAUDE.mdのUser Contextに記載
2. **会社名** — 同上
3. **役割** — ソロ開発 / テックリード / メンバー / 非エンジニア
4. **技術スタック** — Next.js, React Native, Vue, Python, Rails, Go, Swift, Flutter（複数選択可）
5. **DB** — Supabase, Firebase, PostgreSQL, AWS, MySQL
6. **パッケージマネージャ** — pnpm, npm, yarn, bun
7. **Codex利用** — はい / いいえ
8. **チーム運用** — はい / いいえ

## オプションフラグ

| フラグ | 説明 |
|--------|------|
| `--dry-run` | プレビューモード。ファイルを書き込まずに何が生成されるか確認 |
| `--rollback` | 直前のバックアップからsettings.jsonを復元 |
| `--reconfigure` | ヒアリングをやり直す（前回の設定を無視） |
| `--version` | バージョン表示 |
| `--help` | ヘルプ表示 |

## 既存環境との共存

- **settings.json** — 既存設定とマージ（hooks, permissions, deny listを追記。既存は上書きしない）
- **CLAUDE.md** — 既存がある場合はdiff表示。上書き/スキップ/バックアップを選択
- **agents/rules** — 同名ファイルは上書き確認プロンプト
- **バックアップ** — `~/.claude/backups/` に自動保存（直近5世代保持）

## カスタマイズ

インストール後、以下を自由に編集できる:

- `~/CLAUDE.md` — プロジェクト固有のルールを追加
- `~/.claude/agents/` — エージェント定義を調整
- `~/.claude/rules/` — ワークフロールールを変更
- `~/.claude/hooks/*.sh` — hookスクリプトをカスタマイズ

## 含まれるhooks

| Hook | タイミング | 機能 |
|------|-----------|------|
| session-start | セッション開始時 | ブランチ・未コミット変更を表示 |
| block-no-verify | Bash実行前 | `--no-verify` をブロック |
| block-config-edit | ファイル編集前 | linter/formatter設定変更をブロック |
| block-unnecessary-docs | ファイル作成前 | 不要なドキュメントファイル作成をブロック |
| auto-format | ファイル編集後 | Prettierで自動フォーマット |
| typecheck | TS編集後 | TypeScript型チェック |
| console-log-check | ファイル編集後 | console.log残存警告 |
| pre-compact | コンテキスト圧縮前 | ブランチ・コミット情報を保存 |
| stop-console-check | レスポンス後 | 変更ファイルのconsole.logチェック |

## パイプラインパターン（チーム運用向け）

チーム運用を選択すると、Worker/Manager品質ゲートパターンのテンプレートが含まれる。

詳細は `~/.claude/examples/` を参照:
- `pipeline-content.md` — コンテンツ制作パイプライン例
- `pipeline-feature.md` — 機能開発パイプライン例

## 前提条件

- Node.js >= 18
- Git
- macOS または Linux

（不足している場合はインストーラーが案内する）

## ライセンス

MIT

## 開発元

[クレイドル株式会社](https://crdl.co.jp)
