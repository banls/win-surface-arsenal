# proof_msgbox.ps1 —— 最小证明：弹窗 + 上报主机标识（不落盘、不联网可离线跑）
# 用途：确认某条投递链真的能执行代码（比 shell 更轻，AV 几乎不拦）
param([string]$Text = '安全测试载荷执行证明 - Proof of Execution')
Add-Type -AssemblyName System.Windows.Forms
$who = "$env:COMPUTERNAME\$env:USERNAME"
$os  = (Get-CimInstance Win32_OperatingSystem).Caption
$adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
$msg = "$Text`n`n主机: $who`n系统: $os`n管理员: $adm`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
try {
  [System.Windows.Forms.MessageBox]::Show($msg,'Security Self-Test','OK','Information') | Out-Null
} catch {
  # 无桌面会话时回退到控制台
  Write-Host $msg
}
# 同时落一个标记文件（便于远程确认）
"$who | $os | admin=$adm | $(Get-Date -Format s)" | Out-File "$env:TEMP\.proof_$(Get-Date -Format yyyyMMddHHmmss).txt" -Encoding UTF8
