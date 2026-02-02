#!/bin/bash
# ============================================================
# first_setup.sh - multi-agent-bridge 初回セットアップスクリプト
# Ubuntu / WSL / Mac 用環境構築ツール
# ============================================================
# 実行方法:
#   chmod +x first_setup.sh
#   ./first_setup.sh
# ============================================================

set -e

# カラーコード定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}\n"
}

# スクリプト配置ディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ステータス追跡用変数
RESULTS=()
HAS_ERROR=false

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  🚀 multi-agent-bridge インストーラー                           ║"
echo "  ║     Initial Setup Script for Ubuntu / WSL                    ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  本スクリプトは初回セットアップ用である。"
echo "  依存関係の確認とディレクトリ構造の構築を実施する。"
echo ""
echo "  配備先: $SCRIPT_DIR"
echo ""

# ============================================================
# STEP 1: OS チェック
# ============================================================
log_step "STEP 1: システム環境スキャン"

# OS情報を取得
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
    log_info "OS: $OS_NAME $OS_VERSION"
else
    OS_NAME="Unknown"
    log_warn "OS情報を検出できなかった"
fi

# WSL 環境判定
if grep -qi microsoft /proc/version 2>/dev/null; then
    log_info "環境: WSL (Windows Subsystem for Linux)"
    IS_WSL=true
else
    log_info "環境: Native Linux"
    IS_WSL=false
fi

RESULTS+=("システム環境: OK")

# ============================================================
# STEP 2: tmux チェック・インストール
# ============================================================
log_step "STEP 2: tmux チェック"

if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    log_success "tmux 確認完了 (v$TMUX_VERSION)"
    RESULTS+=("tmux: OK (v$TMUX_VERSION)")
else
    log_warn "tmux が未配備である"
    echo ""

    # Ubuntu/Debian系か判定
    if command -v apt-get &> /dev/null; then
        if [ ! -t 0 ]; then
            REPLY="Y"
        else
            read -p "  tmux を配備するか? [Y/n]: " REPLY
        fi
        REPLY=${REPLY:-Y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "tmux 配備中..."
            if ! sudo -n apt-get update -qq 2>/dev/null; then
                if ! sudo apt-get update -qq 2>/dev/null; then
                    log_error "sudo の実行に失敗した。ターミナルから直接実行せよ"
                    RESULTS+=("tmux: 配備失敗 (sudo失敗)")
                    HAS_ERROR=true
                fi
            fi

            if [ "$HAS_ERROR" != true ]; then
                if ! sudo -n apt-get install -y tmux 2>/dev/null; then
                    if ! sudo apt-get install -y tmux 2>/dev/null; then
                        log_error "tmux の配備に失敗した"
                        RESULTS+=("tmux: 配備失敗")
                        HAS_ERROR=true
                    fi
                fi
            fi

            if command -v tmux &> /dev/null; then
                TMUX_VERSION=$(tmux -V | awk '{print $2}')
                log_success "tmux 配備完了 (v$TMUX_VERSION)"
                RESULTS+=("tmux: 配備完了 (v$TMUX_VERSION)")
            else
                log_error "tmux の配備に失敗した"
                RESULTS+=("tmux: 配備失敗")
                HAS_ERROR=true
            fi
        else
            log_warn "tmux の配備をスキップした"
            RESULTS+=("tmux: 未配備 (スキップ)")
            HAS_ERROR=true
        fi
    else
        log_error "apt-get が検出できない。手動で tmux を配備せよ"
        echo ""
        echo "  配備方法:"
        echo "    Ubuntu/Debian: sudo apt-get install tmux"
        echo "    Fedora:        sudo dnf install tmux"
        echo "    macOS:         brew install tmux"
        RESULTS+=("tmux: 未配備 (手動配備が必要)")
        HAS_ERROR=true
    fi
fi

# ============================================================
# STEP 3: tmux マウススクロール設定
# ============================================================
log_step "STEP 3: tmux マウススクロール設定"

TMUX_CONF="$HOME/.tmux.conf"
TMUX_MOUSE_SETTING="set -g mouse on"

if [ -f "$TMUX_CONF" ] && grep -qF "$TMUX_MOUSE_SETTING" "$TMUX_CONF" 2>/dev/null; then
    log_info "tmux マウス設定は既に ~/.tmux.conf に存在する"
else
    log_info "~/.tmux.conf に '$TMUX_MOUSE_SETTING' を追加中..."
    echo "" >> "$TMUX_CONF"
    echo "# マウススクロール有効化 (added by first_setup.sh)" >> "$TMUX_CONF"
    echo "$TMUX_MOUSE_SETTING" >> "$TMUX_CONF"
    log_success "tmux マウス設定を追加した"
fi

# tmux が稼働中の場合は即時反映
if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null; then
    log_info "tmux 稼働中につき、設定を即時反映する..."
    if tmux source-file "$TMUX_CONF" 2>/dev/null; then
        log_success "tmux 設定の再読み込み完了"
    else
        log_warn "tmux 設定の再読み込みに失敗した（手動で tmux source-file ~/.tmux.conf を実行せよ）"
    fi
else
    log_info "tmux は未稼働のため、次回起動時に反映される"
fi

RESULTS+=("tmux マウス設定: OK")

# ============================================================
# STEP 4: Node.js チェック
# ============================================================
log_step "STEP 4: Node.js チェック"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    log_success "Node.js 確認完了 ($NODE_VERSION)"

    # バージョンチェック（18以上推奨）
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | tr -d 'v')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        log_warn "Node.js 18以上を推奨します（現在: $NODE_VERSION）"
        RESULTS+=("Node.js: OK (v$NODE_MAJOR - 要アップグレード推奨)")
    else
        RESULTS+=("Node.js: OK ($NODE_VERSION)")
    fi
else
    log_warn "Node.js が未配備である"
    echo ""

    # nvm が既に配備済みか確認
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        log_info "nvm 検出。Node.js セットアップ開始..."
        \. "$NVM_DIR/nvm.sh"
    else
        # nvm 自動配備
        if [ ! -t 0 ]; then
            REPLY="Y"
        else
            read -p "  Node.js (nvm経由) を配備するか? [Y/n]: " REPLY
        fi
        REPLY=${REPLY:-Y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "nvm 配備中..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        else
            log_warn "Node.js の配備をスキップした"
            echo ""
            echo "  手動で配備する場合:"
            echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
            echo "    source ~/.bashrc"
            echo "    nvm install 20"
            echo ""
            RESULTS+=("Node.js: 未配備 (スキップ)")
            HAS_ERROR=true
        fi
    fi

    # nvm が利用可能なら Node.js を配備
    if command -v nvm &> /dev/null; then
        log_info "Node.js 20 配備中..."
        nvm install 20 || true
        nvm use 20 || true

        if command -v node &> /dev/null; then
            NODE_VERSION=$(node -v)
            log_success "Node.js 配備完了 ($NODE_VERSION)"
            RESULTS+=("Node.js: 配備完了 ($NODE_VERSION)")
        else
            log_error "Node.js の配備に失敗した"
            RESULTS+=("Node.js: 配備失敗")
            HAS_ERROR=true
        fi
    elif [ "$HAS_ERROR" != true ]; then
        log_error "nvm の配備に失敗した"
        echo ""
        echo "  手動で配備せよ:"
        echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
        echo "    source ~/.bashrc"
        echo "    nvm install 20"
        echo ""
        RESULTS+=("Node.js: 未配備 (nvm失敗)")
        HAS_ERROR=true
    fi
fi

# npm 確認
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    log_success "npm 確認完了 (v$NPM_VERSION)"
else
    if command -v node &> /dev/null; then
        log_warn "npm が検出できない（Node.js と同時に配備されるはずだ）"
    fi
fi

# ============================================================
# STEP 5: Claude Code CLI チェック
# ============================================================
log_step "STEP 5: Claude Code CLI チェック"

if command -v claude &> /dev/null; then
    # バージョン取得
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    log_success "Claude Code CLI 確認完了"
    log_info "バージョン: $CLAUDE_VERSION"
    RESULTS+=("Claude Code CLI: OK")
else
    log_warn "Claude Code CLI が未配備である"
    echo ""

    if command -v npm &> /dev/null; then
        echo "  配備コマンド:"
        echo "     npm install -g @anthropic-ai/claude-code"
        echo ""
        if [ ! -t 0 ]; then
            REPLY="Y"
        else
            read -p "  直ちに配備するか? [Y/n]: " REPLY
        fi
        REPLY=${REPLY:-Y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Claude Code CLI 配備中..."
            npm install -g @anthropic-ai/claude-code

            if command -v claude &> /dev/null; then
                log_success "Claude Code CLI 配備完了"
                RESULTS+=("Claude Code CLI: 配備完了")
            else
                log_error "配備に失敗した。パスを確認せよ"
                RESULTS+=("Claude Code CLI: 配備失敗")
                HAS_ERROR=true
            fi
        else
            log_warn "配備をスキップした"
            RESULTS+=("Claude Code CLI: 未配備 (スキップ)")
            HAS_ERROR=true
        fi
    else
        echo "  npm が未配備のため、先に Node.js を配備せよ"
        RESULTS+=("Claude Code CLI: 未配備 (npm必要)")
        HAS_ERROR=true
    fi
fi

# ============================================================
# STEP 6: ディレクトリ構造作成
# ============================================================
log_step "STEP 6: ディレクトリ構造作成"

# 必要ディレクトリ一覧
DIRECTORIES=(
    "queue/tasks"
    "queue/reports"
    "config"
    "status"
    "instructions"
    "logs"
    "demo_output"
    "skills"
    "memory"
)

CREATED_COUNT=0
EXISTED_COUNT=0

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        mkdir -p "$SCRIPT_DIR/$dir"
        log_info "作成: $dir/"
        CREATED_COUNT=$((CREATED_COUNT + 1))
    else
        EXISTED_COUNT=$((EXISTED_COUNT + 1))
    fi
done

if [ $CREATED_COUNT -gt 0 ]; then
    log_success "$CREATED_COUNT 個のディレクトリを構築した"
fi
if [ $EXISTED_COUNT -gt 0 ]; then
    log_info "$EXISTED_COUNT 個のディレクトリは既に存在する"
fi

RESULTS+=("ディレクトリ構造: OK (作成:$CREATED_COUNT, 既存:$EXISTED_COUNT)")

# ============================================================
# STEP 7: 設定ファイル初期化
# ============================================================
log_step "STEP 7: 設定ファイル確認"

# config/settings.yaml
if [ ! -f "$SCRIPT_DIR/config/settings.yaml" ]; then
    log_info "config/settings.yaml を作成中..."
    cat > "$SCRIPT_DIR/config/settings.yaml" << EOF
# multi-agent-bridge 設定ファイル

# 言語設定
# ja: 日本語（UC風軍人口調のみ、併記なし）
# en: 英語（UC風軍人口調 + 英訳併記）
# その他の言語コード（es, zh, ko, fr, de 等）も対応
language: ja

# シェル設定
# bash: bash用プロンプト（デフォルト）
# zsh: zsh用プロンプト
shell: bash

# スキル設定
skill:
  # スキル保存先（スキル名に bridge- プレフィックスを付けて保存）
  save_path: "~/.claude/skills/"

  # ローカルスキル保存先（このプロジェクト専用）
  local_path: "$SCRIPT_DIR/skills/"

# ログ設定
logging:
  level: info  # debug | info | warn | error
  path: "$SCRIPT_DIR/logs/"
EOF
    log_success "settings.yaml を生成した"
else
    log_info "config/settings.yaml は既に存在する"
fi

# config/projects.yaml
if [ ! -f "$SCRIPT_DIR/config/projects.yaml" ]; then
    log_info "config/projects.yaml を作成中..."
    cat > "$SCRIPT_DIR/config/projects.yaml" << 'EOF'
projects:
  - id: sample_project
    name: "Sample Project"
    path: "/path/to/your/project"
    priority: high
    status: active

current_project: sample_project
EOF
    log_success "projects.yaml を生成した"
else
    log_info "config/projects.yaml は既に存在する"
fi

# memory/global_context.md（システム全体のコンテキスト）
if [ ! -f "$SCRIPT_DIR/memory/global_context.md" ]; then
    log_info "memory/global_context.md を作成中..."
    cat > "$SCRIPT_DIR/memory/global_context.md" << 'EOF'
# グローバルコンテキスト
最終更新: (未設定)

## システム方針
- (提督の方針・指示をここに記載)

## プロジェクト横断の決定事項
- (複数プロジェクトに影響する決定をここに記載)

## 注意事項
- (全エージェントが知るべき注意点をここに記載)
EOF
    log_success "global_context.md を生成した"
else
    log_info "memory/global_context.md は既に存在する"
fi

RESULTS+=("設定ファイル: OK")

# ============================================================
# STEP 8: パイロット用タスク・レポートファイル初期化
# ============================================================
log_step "STEP 8: キューファイル初期化"

# パイロット用タスクファイル作成
for i in {1..8}; do
    TASK_FILE="$SCRIPT_DIR/queue/tasks/pilot${i}.yaml"
    if [ ! -f "$TASK_FILE" ]; then
        cat > "$TASK_FILE" << EOF
# パイロット${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    fi
done
log_info "パイロットタスクファイル (1-8) 確認/生成完了"

# パイロット用レポートファイル作成
for i in {1..8}; do
    REPORT_FILE="$SCRIPT_DIR/queue/reports/pilot${i}_report.yaml"
    if [ ! -f "$REPORT_FILE" ]; then
        cat > "$REPORT_FILE" << EOF
worker_id: pilot${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    fi
done
log_info "パイロットレポートファイル (1-8) 確認/生成完了"

RESULTS+=("キューファイル: OK")

# ============================================================
# STEP 9: スクリプト実行権限付与
# ============================================================
log_step "STEP 9: 実行権限設定"

SCRIPTS=(
    "setup.sh"
    "launch.sh"
    "first_setup.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        chmod +x "$SCRIPT_DIR/$script"
        log_info "$script に実行権限を付与した"
    fi
done

RESULTS+=("実行権限: OK")

# ============================================================
# STEP 10: bashrc alias設定
# ============================================================
log_step "STEP 10: alias設定"

# alias追加対象
BASHRC_FILE="$HOME/.bashrc"

# alias既存チェック、なければ追加
ALIAS_ADDED=false

# css alias (艦長ブリッジの起動)
if [ -f "$BASHRC_FILE" ]; then
    EXPECTED_CSS="alias css='tmux attach-session -t bridge'"
    if ! grep -q "alias css=" "$BASHRC_FILE" 2>/dev/null; then
        # alias が存在しない → 新規追加
        echo "" >> "$BASHRC_FILE"
        echo "# multi-agent-bridge aliases (added by first_setup.sh)" >> "$BASHRC_FILE"
        echo "$EXPECTED_CSS" >> "$BASHRC_FILE"
        log_info "alias css を追加した（艦長ブリッジの起動）"
        ALIAS_ADDED=true
    elif ! grep -qF "$EXPECTED_CSS" "$BASHRC_FILE" 2>/dev/null; then
        # alias は存在するがパスが異なる → 更新
        if sed -i "s|alias css=.*|$EXPECTED_CSS|" "$BASHRC_FILE" 2>/dev/null; then
            log_info "alias css を更新した（パス変更検出）"
        else
            log_warn "alias css の更新に失敗した"
        fi
        ALIAS_ADDED=true
    else
        log_info "alias css は既に正しく設定されている"
    fi

    # csm alias (戦術長・パイロットハンガーの起動)
    EXPECTED_CSM="alias csm='tmux attach-session -t hangar'"
    if ! grep -q "alias csm=" "$BASHRC_FILE" 2>/dev/null; then
        if [ "$ALIAS_ADDED" = false ]; then
            echo "" >> "$BASHRC_FILE"
            echo "# multi-agent-bridge aliases (added by first_setup.sh)" >> "$BASHRC_FILE"
        fi
        echo "$EXPECTED_CSM" >> "$BASHRC_FILE"
        log_info "alias csm を追加した（戦術長・パイロットハンガーの起動）"
        ALIAS_ADDED=true
    elif ! grep -qF "$EXPECTED_CSM" "$BASHRC_FILE" 2>/dev/null; then
        if sed -i "s|alias csm=.*|$EXPECTED_CSM|" "$BASHRC_FILE" 2>/dev/null; then
            log_info "alias csm を更新した（パス変更検出）"
        else
            log_warn "alias csm の更新に失敗した"
        fi
        ALIAS_ADDED=true
    else
        log_info "alias csm は既に正しく設定されている"
    fi
else
    log_warn "$BASHRC_FILE が検出できない"
fi

if [ "$ALIAS_ADDED" = true ]; then
    log_success "alias設定を追加した"
    log_warn "alias を反映するには、以下のいずれかを実行せよ："
    log_info "  1. source ~/.bashrc"
    log_info "  2. PowerShell で 'wsl --shutdown' してからターミナルを開き直す"
    log_info "  ※ ウィンドウを閉じるだけでは WSL が終了しないため反映されない"
fi

RESULTS+=("alias設定: OK")

# ============================================================
# STEP 11: Memory MCP セットアップ
# ============================================================
log_step "STEP 11: Memory MCP セットアップ"

if command -v claude &> /dev/null; then
    # Memory MCP 設定状態確認
    if claude mcp list 2>/dev/null | grep -q "memory"; then
        log_info "Memory MCP は既に設定済みである"
        RESULTS+=("Memory MCP: OK (設定済み)")
    else
        log_info "Memory MCP を設定中..."
        if claude mcp add memory \
            -e MEMORY_FILE_PATH="$SCRIPT_DIR/memory/bridge_memory.jsonl" \
            -- npx -y @modelcontextprotocol/server-memory 2>/dev/null; then
            log_success "Memory MCP 設定完了"
            RESULTS+=("Memory MCP: 設定完了")
        else
            log_warn "Memory MCP の設定に失敗した（手動設定可能）"
            RESULTS+=("Memory MCP: 設定失敗 (手動設定可能)")
        fi
    fi
else
    log_warn "claude コマンドが検出できないため Memory MCP 設定をスキップ"
    RESULTS+=("Memory MCP: スキップ (claude未配備)")
fi

# ============================================================
# ステータスレポート
# ============================================================
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  📋 セットアップ ステータスレポート                             ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""

for result in "${RESULTS[@]}"; do
    if [[ $result == *"未配備"* ]] || [[ $result == *"失敗"* ]]; then
        echo -e "  ${RED}✗${NC} $result"
    elif [[ $result == *"アップグレード"* ]] || [[ $result == *"スキップ"* ]]; then
        echo -e "  ${YELLOW}!${NC} $result"
    else
        echo -e "  ${GREEN}✓${NC} $result"
    fi
done

echo ""

if [ "$HAS_ERROR" = true ]; then
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  ⚠️  一部の依存関係が不足している                             ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  上記の警告を確認し、不足分を配備せよ。"
    echo "  全ての依存関係が揃った時点で、再度本スクリプトを実行し確認可能だ。"
else
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  ✅ セットアップ完了！全システム、出撃準備よし！              ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
fi

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  📜 次の作戦行動                                             │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "  出撃（全エージェント発進）:"
echo "     ./launch.sh"
echo ""
echo "  オプション:"
echo "     ./launch.sh -s            # セットアップのみ（Claude手動起動）"
echo "     ./launch.sh -t            # Windows Terminalタブ展開"
echo "     ./launch.sh -shell bash   # bash用プロンプトで発進"
echo "     ./launch.sh -shell zsh    # zsh用プロンプトで発進"
echo ""
echo "  ※ シェル設定は config/settings.yaml の shell: でも変更可能です"
echo ""
echo "  詳細は README.md を参照せよ。"
echo ""
echo "  ════════════════════════════════════════════════════════════════"
echo "   ローンチシークエンス開始！ (Launch Sequence Initiated!)"
echo "  ════════════════════════════════════════════════════════════════"
echo ""

# 依存関係不足時は exit 1 を返す（install.bat が検知するため）
if [ "$HAS_ERROR" = true ]; then
    exit 1
fi
