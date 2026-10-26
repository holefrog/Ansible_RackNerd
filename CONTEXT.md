# CONTEXT.md — 项目当前状态与工作现场

> 本文件记录本项目的**当前开发进度、关键现场信息与决策索引**。每次开启新任务前优先阅读本文档。

---

## 一、 当前工程状态

- **架构状态（2026-10-26 定稿）**：
  - 采用 **2-Role 极简架构**：`roles/security`（访问控制）+ `roles/infrastructure`（系统基建）。
  - 彻底移除了废弃的 `vars/`、Kuma、Nginx、Certbot、VPN、UFW 等历史遗留。
  - 针对 Debian 12 进行了极致瘦身，去掉了所有冗余的 `when: ansible_os_family == 'Debian'`。
- **文档体系**：
  - [README.md](README.md)：项目全局概览与 QuickStart。
  - [AGENTS.md](AGENTS.md)：本项目专属约束与架构铁律。
  - [.agents/AGENTS.md](.agents/AGENTS.md)：通用行为底线。
  - [docs/architecture.md](docs/architecture.md)：系统网络拓扑与执行时序设计。
  - [docs/troubleshooting.md](docs/troubleshooting.md)：SSH 与防火墙故障排查手册。
  - [docs/gcp_ssh_operations_runbook.md](docs/gcp_ssh_operations_runbook.md)：GCP SSH 密钥与端口操作手册。

---

## 二、 关键入口与文件速查

| 文件 | 作用 | 说明 |
|---|---|---|
| `apply.sh` | 运维交互总入口 | 开荒自适应引导 / 密钥生成 / 语法校验 / Deploy / Status / Firewall 同步 |
| `site.yml` | 部署总 Playbook | 顺序执行 `security` 与 `infrastructure` 两个 Role |
| `check_status.yml` | 健康看板 Playbook | 巡检 CPU、内存、Swap、自动补丁与云防火墙吻合度 |
| `hosts.yml` | 主机清单 | 仅存真实公网 IP（`ansible_host`），保障直连 |
| `host_vars/vps_01/` | 单机变量 | `vars.yml` (端口/Swap/时区/多公钥) 与 `secrets.yml` (凭据) |
| `keys/vps_01/` | SSH 密钥对 | 独占存放 `id_ed25519` 密钥对，由 `.gitignore` 保护 |

---

## 三、 Roles 执行时序

### 1. `roles/security`（访问控制）
1. `cloud_firewall_assert.yml`：断言云端防火墙放行策略与代码完全吻合（开荒期允许放行 22 端口，迁移后封死）。
2. `ssh.yml`：
   - 合并导入主控公钥与 `extra_ssh_authorized_keys` 多设备信任公钥。
   - 硬化 `sshd_config`（高位端口 22122，禁用密码、空密码、root 登录）。
   - 处理 Debian 12 `ssh.socket` 冲突，切换至独立 `ssh.service`。
   - 重启 sshd 并通过 `wait_for` 验证 22122 端口连通性。
   - `set_fact` 切换 `ansible_port`，`reset_connection` 刷新长连接。
   - 自动联动 `gcloud` 从 GCP 云防火墙中剥离 22 端口，实现硬封闭环。

### 2. `roles/infrastructure`（系统基建）
1. `system.yml`：全量升级系统包（`apt dist-upgrade`）、安装基础运维工具、配置时区与快捷别名。
2. `bbr_swap.yml`：开启 BBR 内核拥塞控制与 fq 调度，优化内存参数，创建并持久化挂载 2GB Swap。
3. `auto_updates.yml`：安装并启用 `unattended-upgrades` 实现每日安全补丁静默升级。

---

## 四、 核心设计决策 (Decisions Summary)

1. **白板机自适应开荒**：`apply.sh` 在首次部署时若检测到 22122 不可达，自动放行 22 端口作为开荒通道；若缺少私钥自动生成并引导上传 GCP；部署完成后由 Ansible 自动收回 22 端口。
2. **GCP 防火墙为唯一网络守门人**：主机层零 iptables / UFW / Fail2ban，零额外 CPU/IOPS 损耗。
3. **多设备 SSH 公钥支持**：通过 `extra_ssh_authorized_keys` 变量，一次性原子注入多台管理设备公钥。
4. **严格聚焦 Debian 12**：代码扁平，拒绝虚无的跨平台空壳代码。
