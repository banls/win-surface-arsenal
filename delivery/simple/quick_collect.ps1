# quick_collect.ps1 —— 一屏即可看的情报收集（不落盘大文件，只打印）
# 适合"执行链刚通，先确认值不值得深入"的第一分钟
$ErrorActionPreference = 'SilentlyContinue'

function L($k,$v){ "{0,-14} {1}" -f ("[$k]"), $v }

L host     (hostname)
L user     ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
L admin    (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))
L os       ((Get-CimInstance Win32_OperatingSystem).Caption + ' ' + (Get-CimInstance Win32_OperatingSystem).Version)
L build    ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)
L model    ((Get-CimInstance Win32_ComputerSystem).Manufacturer + '/' + (Get-CimInstance Win32_ComputerSystem).Model)
L av       ((Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object { $_.displayName }) -join '; ')
L smb_sign ((Get-SmbServerConfiguration).RequireSecuritySignature)
L smb1     ((Get-SmbServerConfiguration).EnableSMB1Protocol)
L ipv4     ((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne '127.0.0.1'} | ForEach-Object { $_.IPAddress }) -join ' ')
L ipv6     ((Get-NetIPAddress -AddressFamily IPv6 | Where-Object {$_.IPAddress -notlike '::1*'} | ForEach-Object { $_.IPAddress }) -join ' ')

# 同网段邻居（横向线索）
$arp = (arp -a) -join "`n"
$n = [regex]::Matches($arp,'(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F-]{17})') | ForEach-Object { "$($_.Groups[1].Value)|$($_.Groups[2].Value)" }
L neighbors ($n -join ' ')

# 浏览器凭据文件是否存在
foreach($p in @(
  "$env:LOCALAPPDATA\Google\Chrome\User Data\Default",
  "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
  "$env:LOCALAPPDATA\360Chrome\Chrome\User Data\Default"
)){ if(Test-Path $p){ L browser (Split-Path (Split-Path $p) -Leaf) + " LoginData=" + (Test-Path "$p\Login Data") } }

# 保存的凭据数量
L creds ((cmdkey /list | Select-String 'Target:' | Measure-Object).Count)

# 已连接会话（谁在连我）
L sessions ((Get-NetTCPConnection -State Established | Where-Object {$_.RemoteAddress -notmatch '^(127|::1)'} | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)" }) -join ' ')
