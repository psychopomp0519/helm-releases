# ============================================================
#  Helm 셋업 스크립트 — AI 엔진(Claude / Codex) CLI 설치
#  - 엔진만 설치합니다. cursor/vscode/obsidian/ollama 는 Helm 앱 안에서 선택 설치(winget).
#  - 모든 출력이 보이는 투명 설치 (앱 안에 숨기지 않음)
#  - 기존 로그인(.claude / .codex)은 절대 건드리지 않음
#  - PowerShell 5.1(fresh Windows)에서도 동작하도록 TLS 1.2 강제 + curl.exe 우선
#  - 이미 설치돼 있으면 최신으로 갱신(-Update 또는 자동 감지)
#  실행:  irm <raw-url> | iex   또는   powershell -ExecutionPolicy Bypass -File helm-setup.ps1
# ============================================================
param([switch]$Update)

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072  # TLS 1.2

function Say($m,$c='Gray'){ Write-Host $m -ForegroundColor $c }
function Step($n){ Write-Host "`n===== $n =====" -ForegroundColor Cyan }

# 견고한 다운로드: curl.exe(Win10 1803+ 내장) 우선, 없으면 Invoke-WebRequest
function Download($url,$out){
  Say "  다운로드: $url"
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    curl.exe -fL --retry 3 -o $out $url
    if ($LASTEXITCODE -ne 0) { throw "curl 실패(exit $LASTEXITCODE)" }
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out
  }
  if (-not (Test-Path $out)) { throw "다운로드 파일 없음: $out" }
  Say ("  완료: {0:N1} MB" -f ((Get-Item $out).Length/1MB)) Green
}

# 사용자 PATH 에 디렉터리 추가 (영구) + 현재 세션 반영
function Add-UserPath($dir){
  $u = [Environment]::GetEnvironmentVariable('PATH','User')
  if ($u -notlike "*$dir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$dir;$u", 'User')
    Say "  PATH 추가: $dir" Green
  }
  if ($env:PATH -notlike "*$dir*") { $env:PATH = "$dir;$env:PATH" }
}

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Helm 셋업 — AI 엔진(Claude/Codex) 설치" -ForegroundColor Magenta
Write-Host "  (기존 로그인은 보존됩니다)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
Say "감지된 아키텍처: $arch"
$binDir = "$env:LOCALAPPDATA\Helm\bin"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# ---------- 1. Claude Code CLI ----------
Step "1/2  Claude Code CLI"
$haveClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
if ($haveClaude -and -not $Update) {
  Say "  이미 설치됨: $((claude --version 2>$null))  (최신 갱신은 -Update)" Green
} else {
  try {
    if ($haveClaude) { Say "  최신으로 갱신 중 (claude update)..."; claude update 2>&1 | ForEach-Object { Say "    $_" } }
    else {
      Say "  공식 설치 스크립트 실행 (claude.ai/install.ps1)..."
      $ps = "$env:TEMP\claude-install.ps1"
      Download "https://claude.ai/install.ps1" $ps
      & powershell -NoProfile -ExecutionPolicy Bypass -File $ps
    }
    Say "  → claude 완료" Green
  } catch { Say "  ✗ claude 실패: $_" Red; Say "    수동: https://docs.claude.com/en/docs/claude-code/setup" Yellow }
}

# ---------- 2. Codex CLI (독립 실행파일, Node 불필요 / 재다운=최신) ----------
Step "2/2  Codex CLI"
$haveCodex = [bool](Get-Command codex -ErrorAction SilentlyContinue)
if ($haveCodex -and -not $Update) {
  Say "  이미 설치됨: $((codex --version 2>$null))  (최신 갱신은 -Update)" Green
} else {
  try {
    if ($haveCodex) { Say "  최신 바이너리로 갱신 중..." } else { Say "  최신 바이너리 설치 중..." }
    $url = "https://github.com/openai/codex/releases/latest/download/codex-$arch-pc-windows-msvc.exe"
    $dst = "$binDir\codex.exe"
    Download $url $dst
    if ((Get-Item $dst).Length -lt 1MB) { throw "codex 파일이 너무 작음(손상)" }
    Add-UserPath $binDir
    Say "  설치 위치: $dst" Green
    Say "  버전: $((& $dst --version 2>$null))" Green
  } catch { Say "  ✗ codex 실패: $_" Red; Say "    수동: https://developers.openai.com/codex/cli" Yellow }
}

# ---------- 결과 ----------
Step "결과"
function Check($name,$cmd){
  $g = Get-Command $cmd -ErrorAction SilentlyContinue
  if ($g) { Say ("  [O] {0,-8} {1}" -f $name, (& $cmd --version 2>$null | Select-Object -First 1)) Green }
  else    { Say ("  [X] {0,-8} 미설치 — 위 로그 확인" -f $name) Red }
}
Check 'claude' 'claude'
Check 'codex'  'codex'

Write-Host "`n로그인 보존 상태:" -ForegroundColor Cyan
Say ("  .claude: {0}" -f (Test-Path "$env:USERPROFILE\.claude\.credentials.json"))
Say ("  .codex : {0}" -f (Test-Path "$env:USERPROFILE\.codex\auth.json"))

Write-Host "`n다음 단계:" -ForegroundColor Magenta
Say "  - cursor/vscode/obsidian/ollama 는 Helm 앱 안에서 '쓸 거야?' 물어보고 선택 설치합니다."
Say "  1) 이 창을 닫고 Helm 을 (재)실행하세요. (PATH 반영)"
Say "  2) 미설치([X])가 있으면 위 로그 줄을 그대로 알려주세요."
Write-Host ""
