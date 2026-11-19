param([string[]]$GodotArgs,[string]$Name='check',[int]$Seconds=150,[int]$MemoryMB=850,[string]$ProjectPath='')
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $repoRoot
$previousAppData=$env:APPDATA
$previousLocalAppData=$env:LOCALAPPDATA
try {
$env:APPDATA=Join-Path $repoRoot 'work/qa/AppData'
$env:LOCALAPPDATA=Join-Path $repoRoot 'work/qa/LocalAppData'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$runLog=Join-Path $repoRoot ('work/qa/'+$Name+'.log')
$runErr=Join-Path $repoRoot ('work/qa/'+$Name+'.err')
$engineRoot=if($ProjectPath){[IO.Path]::GetFullPath($ProjectPath)}else{$repoRoot}
$runArgs=@('--path',('"'+$engineRoot+'"'))+$GodotArgs
$godotExe=if($env:GODOT_BIN){$env:GODOT_BIN}else{'D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'}
$runProc=Start-Process -FilePath $godotExe -ArgumentList $runArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $runLog -RedirectStandardError $runErr
$runProc.PriorityClass='BelowNormal'
$runStart=Get-Date
$runPeak=0L
while(-not $runProc.HasExited){
 $runProc.Refresh()
 $runPeak=[Math]::Max($runPeak,$runProc.WorkingSet64)
 if(((Get-Date)-$runStart).TotalSeconds -gt $Seconds -or $runProc.WorkingSet64 -gt ($MemoryMB*1MB)){Stop-Process -Id $runProc.Id; Write-Output 'WATCHDOG';break}
 Start-Sleep -Milliseconds 200
}
$runProc.WaitForExit()
$issues=@(Select-String -Path $runLog,$runErr -Pattern 'SCRIPT ERROR|ERROR:|WARNING:')
Write-Output ($Name+' exit='+$runProc.ExitCode+' diagnostics='+$issues.Count+' peakMB='+[Math]::Round($runPeak/1MB,1))
Get-Content $runLog -Tail 3
if($issues.Count -gt 0){Get-Content $runErr -TotalCount 22}
if($runProc.ExitCode -ne 0 -or $issues.Count -gt 0){exit 1}
exit 0
} finally {
 $env:APPDATA=$previousAppData
 $env:LOCALAPPDATA=$previousLocalAppData
}
