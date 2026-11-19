param(
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9][0-9A-Za-z._-]*$')][string]$Version,
 [string]$GodotBin=$env:GODOT_BIN
)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $repoRoot
if (-not $GodotBin) { $GodotBin='D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw 'Set GODOT_BIN to the installed Godot 4.7.2 editor.' }
$env:GODOT_BIN=$GodotBin
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI is required to upload the separate beta Release asset.' }
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication is required.' }
$tag='v'+$Version
& git rev-parse --verify --quiet ('refs/tags/'+$tag) *> $null
if ($LASTEXITCODE -eq 0) { throw 'Version already exists. Published tags are never overwritten.' }
# Complete local validation and playable build before touching the remote repository.
& tools/qa/run_godot.ps1 -Name release_import -GodotArgs @('--headless','--editor','--import','--quit') -MemoryMB 1800
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
& tools/qa/run_godot.ps1 -Name release_units -GodotArgs @('--headless','--script','res://test/run_tests.gd')
if ($LASTEXITCODE -ne 0) { throw 'Unit tests failed.' }
foreach ($check in @('tools/qa/audit_repository.py','tools/qa/validate_data.py')) {
 & python -X utf8 $check
 if ($LASTEXITCODE -ne 0) { throw ('Validation failed: '+$check) }
}
& python -X utf8 tools/release/prepare_beta.py --version $Version
if ($LASTEXITCODE -ne 0) { throw 'Beta staging failed.' }
$releaseRoot=Join-Path $repoRoot ('work/releases/'+$Version)
$stage=Join-Path $releaseRoot 'project'
$game=Join-Path $releaseRoot 'game'
New-Item -ItemType Directory -Force -Path $game | Out-Null
& tools/qa/run_godot.ps1 -Name beta_import -ProjectPath $stage -GodotArgs @('--headless','--editor','--import','--quit') -MemoryMB 1800
if ($LASTEXITCODE -ne 0) { throw 'Beta import failed.' }
& tools/qa/run_godot.ps1 -Name beta_export -ProjectPath $stage -GodotArgs @('--headless','--export-release','"Windows Beta"',('"'+(Join-Path $game 'Naibao.exe')+'"')) -MemoryMB 1800
if ($LASTEXITCODE -ne 0) { throw 'Playable export failed. Install the matching Godot Windows export template. Preserve the staging folder and continue its beta_export step; no source-only substitute is published.' }
$exe=Join-Path $game 'Naibao.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Missing playable beta executable.' }
$smoke=Start-Process -FilePath $exe -ArgumentList @('--headless','--quit-after','120','--max-fps','60','--log-file',('"'+(Join-Path $releaseRoot 'smoke.log')+'"')) -WindowStyle Hidden -PassThru
if (-not $smoke.WaitForExit(30000)) { Stop-Process -Id $smoke.Id; throw 'Exported beta startup timed out.' }
if ($smoke.ExitCode -ne 0 -or (Select-String -LiteralPath (Join-Path $releaseRoot 'smoke.log') -Pattern 'ERROR:|SCRIPT ERROR' -Quiet)) { throw 'Exported beta smoke failed.' }
'奶宝：银河征途 beta '+$Version+"`n双击 Naibao.exe 启动。A/D移动，Space跳跃，左键攻击，右键格挡，E交互。" | Set-Content -LiteralPath (Join-Path $game 'README.txt') -Encoding utf8
$zip=Join-Path $releaseRoot ('Naibao-'+$Version+'-windows-beta.zip')
Compress-Archive -Path (Join-Path $game '*') -DestinationPath $zip
Get-FileHash -Algorithm SHA256 -LiteralPath $zip | Format-List | Out-File -LiteralPath ($zip+'.sha256.txt') -Encoding utf8
# Stamp the source version only after the requested release build has passed.
$project=Join-Path $repoRoot 'project.godot'
$config=Get-Content -Raw -LiteralPath $project
$config=[regex]::Replace($config,'(?m)^config/version=.*\r?\n','')
$config=$config.Replace('[application]',('[application]'+"`n`nconfig/version="+'"'+$Version+'"'))
[IO.File]::WriteAllText($project,$config,[Text.UTF8Encoding]::new($false))
& git add -A
& git commit -m ('chore(release): '+$Version+' beta')
if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
& git tag $tag
if ($LASTEXITCODE -ne 0) { throw 'Tag failed.' }
& git push origin HEAD
if ($LASTEXITCODE -ne 0) { throw 'Source push failed; local release retained.' }
& git push origin $tag
if ($LASTEXITCODE -ne 0) { throw 'Tag push failed; local release retained.' }
$body=Join-Path $releaseRoot 'release_notes.md'
'Windows x64 beta。双击 Naibao.exe 可运行。附件不含测试、制作工具、原始素材、存档及缓存。' | Set-Content -LiteralPath $body -Encoding utf8
& gh release create $tag $zip ($zip+'.sha256.txt') --verify-tag --prerelease --title ('奶宝：银河征途 '+$Version+' beta') --notes-file $body
if ($LASTEXITCODE -ne 0) { throw 'Beta upload failed; retry asset upload for this existing tag without recreating the version.' }
