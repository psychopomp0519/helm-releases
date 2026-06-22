# ============================================================
#  Helm 셋업 스크립트 — Claude / Codex / Ollama CLI 설치
#  - 모든 출력이 보이는 투명 설치 (앱 안에 숨기지 않음)
#  - 기존 로그인(.claude / .codex)은 절대 건드리지 않음
#  - PowerShell 5.1(fresh Windows)에서도 동작하도록 TLS 1.2 강제 + curl.exe 우선
#  실행:  powershell -ExecutionPolicy Bypass -File helm-setup.ps1
#  옵션:  -SkipOllama  (로컬 라우터 AI 불필요 시)
# ============================================================
param([switch]$SkipOllama)

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
Write-Host "  Helm 셋업 — CLI 엔진 설치" -ForegroundColor Magenta
Write-Host "  (기존 로그인은 보존됩니다)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
Say "감지된 아키텍처: $arch"
$binDir = "$env:LOCALAPPDATA\Helm\bin"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# ---------- 1. Claude Code CLI ----------
Step "1/3  Claude Code CLI"
if (Get-Command claude -ErrorAction SilentlyContinue) {
  Say "  이미 설치됨: $((claude --version 2>$null))" Green
} else {
  try {
    Say "  공식 설치 스크립트 실행 (claude.ai/install.ps1)..."
    $ps = "$env:TEMP\claude-install.ps1"
    Download "https://claude.ai/install.ps1" $ps
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ps
    Say "  → claude 설치 시도 완료" Green
  } catch { Say "  ✗ claude 설치 실패: $_" Red; Say "    수동: https://docs.claude.com/en/docs/claude-code/setup" Yellow }
}

# ---------- 2. Codex CLI (독립 실행파일, Node 불필요) ----------
Step "2/3  Codex CLI"
if (Get-Command codex -ErrorAction SilentlyContinue) {
  Say "  이미 설치됨: $((codex --version 2>$null))" Green
} else {
  try {
    $url = "https://github.com/openai/codex/releases/latest/download/codex-$arch-pc-windows-msvc.exe"
    $dst = "$binDir\codex.exe"
    Download $url $dst
    if ((Get-Item $dst).Length -lt 1MB) { throw "codex 파일이 너무 작음(손상)" }
    Add-UserPath $binDir
    Say "  설치 위치: $dst" Green
    Say "  버전: $((& $dst --version 2>$null))" Green
  } catch { Say "  ✗ codex 설치 실패: $_" Red; Say "    수동: https://developers.openai.com/codex/cli" Yellow }
}

# ---------- 3. Ollama (로컬 라우터 AI · 선택) ----------
Step "3/3  Ollama (선택 — 로컬 라우터 AI)"
if ($SkipOllama) {
  Say "  건너뜀 (-SkipOllama)"
} elseif (Get-Command ollama -ErrorAction SilentlyContinue) {
  Say "  이미 설치됨: $((ollama --version 2>$null))" Green
} else {
  try {
    $o = "$env:TEMP\OllamaSetup.exe"
    Download "https://ollama.com/download/OllamaSetup.exe" $o
    Say "  무인 설치 중 (/VERYSILENT)..."
    Start-Process -FilePath $o -ArgumentList '/VERYSILENT','/NORESTART' -Wait
    Say "  → ollama 설치 완료" Green
  } catch { Say "  ✗ ollama 설치 실패: $_" Red; Say "    수동: https://ollama.com/download" Yellow }
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
if (-not $SkipOllama) { Check 'ollama' 'ollama' }

Write-Host "`n로그인 보존 상태:" -ForegroundColor Cyan
Say ("  .claude: {0}" -f (Test-Path "$env:USERPROFILE\.claude\.credentials.json"))
Say ("  .codex : {0}" -f (Test-Path "$env:USERPROFILE\.codex\auth.json"))

Write-Host "`n다음 단계:" -ForegroundColor Magenta
Say "  1) 이 창을 닫고 Helm 을 (재)실행하세요. (PATH 반영을 위해)"
Say "  2) 미설치([X])가 있으면 위 로그 줄을 그대로 알려주세요."
Write-Host ""
