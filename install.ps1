<#
  One-liner install of the newest Creatorize Suite no-Skool build (Windows 10/11 x64).

  Paste into PowerShell:

    irm https://raw.githubusercontent.com/marifaceless/creatorize-noskool/main/install.ps1 | iex

  Downloads the latest Setup.exe, checks it against the release's own sha256, installs it silently,
  then starts it. It updates itself from then on.
#>

$ErrorActionPreference = 'Stop'
$repo = 'marifaceless/creatorize-noskool'
$progressPreference = 'SilentlyContinue'

function Say($m) { Write-Host $m }
function Die($m) { Write-Host ''; Write-Host "Stopped: $m" -ForegroundColor Red; Write-Host ''; throw $m }

try {
  # works on both Windows PowerShell 5.1 and 7: $IsWindows does not exist in 5.1
  $IsWin = ($env:OS -eq 'Windows_NT')
  if (-not $IsWin) { Die 'this is the Windows installer. On macOS use get.sh instead.' }
  if (-not [Environment]::Is64BitOperatingSystem) { Die 'this build is for 64-bit Windows.' }

  $headers = @{ 'accept' = 'application/vnd.github+json'; 'user-agent' = 'creatorize-noskool' }

  Say 'Looking up the newest build ...'
  $tag = $null
  try {
    $releases = Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri "https://api.github.com/repos/$repo/releases?per_page=5"
    $tag = ($releases | Where-Object { -not $_.draft -and -not $_.prerelease } | Select-Object -First 1).tag_name
  } catch {
    # GitHub's API allows 60 calls an hour per network; fall back to the latest-release redirect
    $r = Invoke-WebRequest -UseBasicParsing -MaximumRedirection 10 -Uri "https://github.com/$repo/releases/latest"
    if ($r.BaseResponse.ResponseUri -match '/releases/tag/([^/?#]+)') { $tag = $Matches[1] }
  }
  if (-not $tag) { Die 'no release found.' }
  $ver = $tag -replace '^v', ''
  Say "newest build: $tag"

  $base = "https://github.com/$repo/releases/download/$tag"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("cz-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null

  $manifestPath = Join-Path $tmp 'update-manifest.json'
  Invoke-WebRequest -UseBasicParsing -Uri "$base/update-manifest.json" -OutFile $manifestPath
  $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
  if ($manifest.version -ne $ver) { Die "the manifest is for $($manifest.version), expected $ver." }

  $setupName = "Creatorize-Suite-Setup-$ver.exe"
  $want = $manifest.assets.$setupName.sha256
  if (-not $want) { Die "this release has no Windows installer ($setupName)." }

  $size = [math]::Round($manifest.assets.$setupName.size / 1MB)
  Say "downloading $setupName (about $size MB) ..."
  $setup = Join-Path $tmp $setupName
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$setupName" -OutFile $setup

  $have = (Get-FileHash -Algorithm SHA256 -Path $setup).Hash.ToLower()
  if ($have -ne $want.ToLower()) { Die "the download does not match its checksum ($have). Run it again." }
  Say 'checksum ok'

  Unblock-File -Path $setup
  if (-not $IsWin) { Say 'checksum ok — install steps skipped (not running on Windows)'; return }

  $running = Get-Process -Name 'Creatorize Suite' -ErrorAction SilentlyContinue
  if ($running) { Say 'closing Creatorize Suite ...'; $running | Stop-Process -Force; Start-Sleep -Seconds 2 }

  Say 'installing (silent) ...'
  $p = Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru
  if ($p.ExitCode -ne 0) { Die "the installer returned $($p.ExitCode). Try the Setup.exe from the release page by hand." }

  $exe = Join-Path $env:LOCALAPPDATA 'Programs\Creatorize Suite\Creatorize Suite.exe'
  if (Test-Path $exe) { Say 'done. opening it ...'; Start-Process -FilePath $exe }
  else { Say "done, but the app was not where expected. Start it from the Start menu." }

  Say ''
  Say 'It opens on Home with Premium unlocked, no sign-in. Next: "Connect Claude" on Home with your own Claude account.'
  Say 'This copy updates itself (it offers new versions in Settings > Updates).'
  Say 'Windows may say "Windows protected your PC" the first time: More info > Run anyway.'
  Write-Host "Press Enter to close." -ForegroundColor DarkGray
  if ($Host.Name -eq 'ConsoleHost') { [void](Read-Host) }
} catch {
  Say ''
  Say 'If this keeps failing, install by hand:'
  Say "  https://github.com/$repo/releases/latest  ->  Assets  ->  Creatorize-Suite-Setup-*.exe"
  Say 'More info > Run anyway if Windows warns you.'
} finally {
  if ($tmp -and (Test-Path $tmp)) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
