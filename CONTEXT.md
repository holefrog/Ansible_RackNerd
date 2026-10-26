# CONTEXT.md — 项目当前状态与工作现场

> 本文件记录本项目的**当前开发进度、关键现场信息与决策索引**。每次开启新任务前优先阅读本文档。

---

## 一、 当前工程状态

- **架构状态（2026-10-26 重构完成）**：
  - 采用 **4-Role 模块化架构**：`roles/security`（访问控制）+ `roles/infrastructure`（系统基建）+ `roles/application`（应用服务）+ `roles/vpn`（代理网络）。
  - 对齐 GCP 标准：重构了 `roles/security` 与 `roles/infrastructure`，拆分单一职责文件。
  - 彻底删除了无用的 `fail2ban`（含模板与 handler），释放内存与磁盘 IO。
  - 彻底删除了跨系统冗余 `vars/`（Debian.yml/RedHat.yml），针对 Debian 12 极致瘦身，清除了所有 `when: ansible_os_family == 'Debian'`。
  - 实现了 **22122 端口热切换与 UFW 22 端口自动化闭环硬封**，免去人工手动锁门。
- **文档体系**：
  - [README.md](README.md)：项目全局概览、架构解析与 QuickStart。
  - [AGENTS.md](AGENTS.md)：本项目专属约束与架构铁律。
  - [.agents/AGENTS.md](.agents/AGENTS.md)：通用行为底线。

---

## 二、 关键入口与文件速查

| 文件 | 作用 | 说明 |
|---|---|---|
| `apply.sh` | 运维交互总入口 | 部署环境校验 / 语法校验 / 白板机开荒自适应探测与公钥自动注入 / Deploy / Status 巡检看板 |
| `site.yml` | 部署总 Playbook | 顺序执行 `security`, `infrastructure`, `application`, `vpn` |
| `check_status.yml` | 健康看板 Playbook | 巡检 CPU、内存、Swap、核心服务、WebDAV 路由及 22 端口闭锁状态 |
| `close_22.sh` | 应急手动锁门脚本 | 备用工具（正常由 Ansible 部署流自动切断） |
| `remote_login.sh` | 快捷免密登录脚本 | 零参数默认直连 `vps_primary`，自动激活状态栏配色 |
| `hosts.yml` | 主机清单 | 仅存真实公网 IP（`ansible_host`），保障直连 |
| `host_vars/vps_primary/` | 单机变量 | `vars.yml` (端口/Swap/时区/域名等) 与 `secrets.yml` (凭据) |
| `keys/` | SSH 密钥目录 | 存放私钥对，由 `.gitignore` 保护 |

---

## 三、 Roles 执行时序

### 1. `roles/security`（访问控制）
1. `firewall.yml`：基于 UFW 放行高位端口 `{{ ssh_port }}` (22122)、80、443，部署期间暂留 22 防自锁。
2. `ssh.yml`：
   - 合并导入主控公钥与 `extra_ssh_authorized_keys` 多设备信任公钥。
   - 硬化 `sshd_config`（高位端口 22122，禁用密码、空密码，限制 root 密码登录）。
   - 处理 Debian 12 `ssh.socket` 冲突，切换至独立 `ssh.service`。
   - 重启 sshd 并通过本地 `wait_for` 验证 22122 端口连通性。
   - `set_fact` 切换 `ansible_port`，`reset_connection` 刷新长连接。
   - **自动化闭环**：直接调用 UFW 模块删除 22 端口放行规则，实现硬封闭环。

### 2. `roles/infrastructure`（系统基建）
1. `system.yml`：全量升级系统包（`apt dist-upgrade`）、安装基础运维工具、配置时区、快捷别名与自定义 logrotate。
2. `bbr_swap.yml`：开启 BBR 内核拥塞控制与 fq 调度，优化内存参数，创建并持久化挂载 2GB Swap。
3. `auto_updates.yml`：安装并启用 `unattended-upgrades` 实现每日安全补丁静默升级。
4. `nginx.yml`：安装 Nginx 及证书管理，配置 443 端口 Stream TLS SNI 预读分流骨架。
5. `ddns.yml`：动态域名解析同步。

### 3. `roles/application`（应用服务）
1. `aria2.yml`：部署 Aria2 下载服务并注入 Nginx 路由。
2. `webdav.yml`：部署 WebDAV 文件共享服务及前端增强脚本。

### 4. `roles/vpn`（代理网络）
1. Xray 官方安装、密钥自愈、服务端配置、Nginx 回源集成与客户端凭证分发。

---

## 四、 核心设计决策 (Decisions Summary)

1. **白板机自适应开荒**：`apply.sh` 前置自检目标主机认证状态。若机器刚重置且私钥无法登录，自动校验 `secrets.yml` 中的 `ansible_ssh_pass`，并调用 `sshpass + ssh-copy-id` 原子注入本地 Ed25519 公钥；密码错误时提供明确指引，密码正确则无缝转入纯密钥加固流水线。
2. **UFW 守门与零 Fail2ban**：高位端口 22122 + 纯密钥认证，杜绝盲扫打爆日志，彻底移除 Fail2ban 降低资源开销。
3. **多设备 SSH 公钥支持**：通过 `extra_ssh_authorized_keys` 变量，一次性原子注入多台管理设备公钥。
4. **严格聚焦 Debian 12**：代码扁平，拒绝虚无的跨平台空壳代码。
5. **单机专属收敛**：彻底抛弃 `group_vars`，所有单机配置集中在 `host_vars/vps_primary/`，快捷工具零参数自适应。
