#!/usr/bin/env bash
# ============================================================
#  Helm 셋업 (Linux / WSL) — AI 엔진(Claude / Codex) CLI 설치
#  - 엔진만 설치. cursor/vscode/obsidian/ollama 는 Helm 앱 안에서 선택 설치.
#  - 기존 로그인(~/.claude / ~/.codex)은 건드리지 않음
#  - 이미 있으면 최신 갱신
#  실행:  curl -fsSL <raw-url> | bash    또는    bash helm-setup.sh
# ============================================================
set -u
say(){ printf '%s\n' "$*"; }
step(){ printf '\n===== %s =====\n' "$*"; }

BIN="$HOME/.local/bin"; mkdir -p "$BIN"
case "$(uname -m)" in aarch64|arm64) ARCH=aarch64;; *) ARCH=x86_64;; esac
say "아키텍처: $ARCH"

# ---------- 1. Claude Code CLI ----------
step "1/2  Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  say "  이미 설치됨: $(claude --version 2>/dev/null) — 최신 갱신 시도"
  claude update 2>&1 | sed 's/^/    /' || true
else
  say "  설치 중 (claude.ai/install.sh)..."
  if curl -fsSL https://claude.ai/install.sh | bash; then say "  ✓ claude 완료"; else say "  ✗ claude 실패 → https://docs.claude.com/en/docs/claude-code/setup"; fi
fi

# ---------- 2. Codex CLI (독립 바이너리, Node 불필요) ----------
step "2/2  Codex CLI"
if command -v codex >/dev/null 2>&1 && [ "${1:-}" != "--update" ]; then
  say "  이미 설치됨: $(codex --version 2>/dev/null)"
else
  URL="https://github.com/openai/codex/releases/latest/download/codex-${ARCH}-unknown-linux-musl.tar.gz"
  say "  최신 바이너리 다운로드: $URL"
  if curl -fsSL "$URL" | tar xz -C "$BIN" 2>/dev/null; then
    mv "$BIN"/codex-*-unknown-linux-musl "$BIN/codex" 2>/dev/null || true
    chmod +x "$BIN/codex" 2>/dev/null
    say "  ✓ codex: $("$BIN/codex" --version 2>/dev/null)"
  else say "  ✗ codex 실패 → https://developers.openai.com/codex/cli"; fi
fi

# ~/.local/bin 을 PATH에 추가 (현재 셸 + ~/.bashrc 영구) — claude/codex 가 잡히게
case ":$PATH:" in *":$BIN:"*) : ;; *) export PATH="$BIN:$PATH" ;; esac
RC="$HOME/.bashrc"
if [ -f "$RC" ] && ! grep -q '\.local/bin' "$RC"; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC"
  say ""
  say "  PATH 영구 추가됨: ~/.bashrc (새 터미널부터 자동, 지금 창은 아래 한 줄)"
  say "    source ~/.bashrc"
fi

# ---------- 결과 ----------
step "결과"
chk(){ if command -v "$1" >/dev/null 2>&1; then say "  [O] $1  $($1 --version 2>/dev/null | head -1)"; else say "  [X] $1  미설치 — 위 로그 확인"; fi; }
chk claude; chk codex
say ""
say "로그인 보존: .claude=$([ -f "$HOME/.claude/.credentials.json" ] && echo O || echo X)  .codex=$([ -f "$HOME/.codex/auth.json" ] && echo O || echo X)"
say "다음: cursor/vscode/obsidian/ollama 는 Helm 앱 안에서 선택 설치."
