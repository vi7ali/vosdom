[CmdletBinding()]
param(
  [string] $RemoteUser    = $(if ($env:VOSDOM_REMOTE_USER) { $env:VOSDOM_REMOTE_USER } else { 'deploy' }),
  [string] $RemoteHost    = $(if ($env:VOSDOM_REMOTE_HOST) { $env:VOSDOM_REMOTE_HOST } else { 'vosdom-vps' }),
  [string] $RemoteDocroot = '/var/www/vosdom',
  [string] $RemoteStaging = '/tmp/vosdom-deploy',
  [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }

# Resolve hugo (must be on PATH; install via winget/scoop/brew etc.)
$hugo = (Get-Command hugo -ErrorAction SilentlyContinue).Source
if (-not $hugo) { Fail 'hugo not on PATH. Install Hugo Extended (e.g. `winget install Hugo.Hugo.Extended`) and open a new shell.' }

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { Fail 'ssh not on PATH (install Git for Windows)' }
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) { Fail 'scp not on PATH (install Git for Windows)' }

# Step 1: build
if (-not $SkipBuild) {
  Step 'Building site (hugo --minify)'
  & $hugo --minify
  if ($LASTEXITCODE -ne 0) { Fail "hugo build failed (exit $LASTEXITCODE)" }
}

# Step 2: sanity check
$index = Join-Path $repoRoot 'public\index.html'
if (-not (Test-Path $index)) { Fail 'public\index.html missing - build produced no output' }
$indexSize = (Get-Item $index).Length
if ($indexSize -lt 100) { Fail "public\index.html suspiciously small: $indexSize bytes" }

$remote = '{0}@{1}' -f $RemoteUser, $RemoteHost

# Step 3: remote staging dir (use ; instead of && for PowerShell-safe local invocation)
Step "Preparing remote staging dir $RemoteStaging on $RemoteHost"
$prep = "rm -rf '$RemoteStaging'; mkdir -p '$RemoteStaging'"
ssh $remote $prep
if ($LASTEXITCODE -ne 0) { Fail 'could not prepare remote staging dir' }

# Step 4: upload via scp (use public/. to include any dotfiles)
Step "Uploading public/ to ${remote}:$RemoteStaging"
scp -r -q 'public/.' "${remote}:$RemoteStaging/"
if ($LASTEXITCODE -ne 0) { Fail 'scp upload failed' }

# Step 5: server-side rsync staging -> docroot, then clean staging.
# The && inside this string is bash, not PowerShell - it runs on the remote.
Step "Syncing $RemoteStaging -> $RemoteDocroot (rsync --delete)"
$remoteCmd = "rsync -a --delete '$RemoteStaging/' '$RemoteDocroot/' && rm -rf '$RemoteStaging'"
ssh $remote $remoteCmd
if ($LASTEXITCODE -ne 0) { Fail "remote rsync failed - check $RemoteDocroot ownership and perms" }

Write-Host ''
Write-Host 'Deploy complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Verification - please do all three before walking away:' -ForegroundColor Yellow
Write-Host '  1. curl -sI https://vosdom.space            (expect 200, valid cert)'
Write-Host '  2. Open https://vosdom.space in a browser   (real content visible, menu works)'
