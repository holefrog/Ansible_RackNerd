# AGENTS.md — Ansible GCP/VPS 项目协作规范

> 本文件是本项目的**唯一业务规范源**。通用行为底线见 [.agents/AGENTS.md](.agents/AGENTS.md)。

## 1. 项目定位与环境约束

- **目标系统**：Debian 12 64-bit（GCP `e2-micro` / 主流 KVM VPS）。
- **执行方式**：Ansible Playbook（主控端为 Linux / macOS，托管端基于 SSH 密钥连接）。
- **执行入口**：常规操作优先调用 `./apply.sh`（内置语法与环境校验）。

---

## 2. 核心网络与架构铁律

1. **变量极致隔离**：
   - **严禁使用 `group_vars`**。所有单机配置必须且只能存放于 `host_vars/<主机名>/`。
   - `vars.yml` 存放公开配置；`secrets.yml` 存放敏感凭证并由 `.gitignore` 保护。
2. **网络连通与业务域名解耦**：
   - `hosts.yml` 必须填写 VPS 实际公网 IP（`ansible_host`），保障 SSH 连通性。
3. **防火墙端口策略**：
   - GCP VPC 防火墙只放行 `ssh_port`（22122）和 `app_port`（3000），默认 22 端口必须封锁。
   - 端口策略必须通过 `cloud_firewall_assert.yml` 代码级断言，禁止仅靠控制台手动配置。

---

## 3. 安全基线铁律 (零冗余、低开销、真防护)

1. **GCP 云端防火墙作为唯一真相源**：
   - 主机层不安装 UFW / Fail2ban（零 CPU/IOPS 开销）。
   - 所有放行规则（`ssh_port`、`app_port`）必须在代码中强制断言，杜绝控制台手动漂移。
2. **SSH 零密码高位加固**：
   - 默认 22 端口彻底切断（GCP 防火墙层 + sshd 不监听双重保障）。
   - 迁移至高位端口 `ssh_port`（22122），杜绝盲扫打爆 auth.log。
   - 仅允许 Ed25519 纯密钥认证，关闭密码登录、空密码、root 直接登录。
3. **SSH 端口热切换与开荒闭环**：
   - 执行时序：自适应探测高位端口 → 开荒时放行 22 端口 → 原子部署公钥（主控公钥 + `extra_ssh_authorized_keys` 多设备密钥） → 修改 sshd → `wait_for` 验证新端口 → `set_fact` 切换端口 → `reset_connection` → 自动剥离云端 22 端口实现硬封。
   - `site.yml` pre_task 先探测新端口是否可达，不可达则 fallback 到 22，保障白板开荒不锁死。
   - `apply.sh` 前置拦截：缺失私钥时自动生成带用户名注释的 Ed25519 密钥对，并引导用户上传至 GCP。
4. **自动安全补丁**：
   - 启用 `unattended-upgrades` 自动安装安全更新，归属 `infrastructure` role。

---

## 4. Roles 职责边界

- **`roles/security`**：访问控制层。负责 GCP 云端防火墙代码级断言 + SSH 纯密钥高位加固（改端口、禁密码、禁 root）。
- **`roles/infrastructure`**：系统基建层。负责系统初始化（全量更新、基础工具、时区）、BBR 拥塞控制、Swap 虚拟内存、`unattended-upgrades` 自动安全补丁。

---

开始任务前先读 @CONTEXT.md
