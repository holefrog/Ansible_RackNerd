# AGENTS.md — Ansible RackNerd 项目协作规范

> 本文件是本项目的**唯一业务规范源**。通用行为底线见 [.agents/AGENTS.md](.agents/AGENTS.md)。

## 1. 项目定位与环境约束

- **目标系统**：Debian 12 64-bit（RackNerd 等主流 KVM VPS）。
- **执行方式**：Ansible Playbook（主控端为 Linux / macOS，托管端基于 SSH 密钥连接）。
- **执行入口**：常规操作优先调用 `./apply.sh`（内置语法校验、白板机开荒探测与部署总入口）。

---

## 2. 核心网络与架构铁律

1. **变量极致隔离**：
   - **严禁使用 `group_vars`**。所有单机配置必须且只能存放于 `host_vars/<主机名>/`。
   - `vars.yml` 存放公开配置；`secrets.yml` 存放敏感凭证并由 `.gitignore` 保护。
2. **网络连通与业务域名解耦**：
   - `hosts.yml` 必须填写 VPS 实际公网 IP（`ansible_host`），保障 SSH 连通性。
3. **防火墙与端口策略**：
   - UFW 仅放行业务端口（`80`, `443`）与高位 SSH 端口（`ssh_port: 22122`），默认 22 端口必须封死。
   - 内部服务端口（Aria2 `6800`, Xray `10086`, Nginx internal `4433`）对公网严格隐身。

---

## 3. 安全基线铁律 (零冗余、低开销、真防护)

1. **主机防火墙与零 Fail2ban 开销**：
   - 依赖 UFW 守护端口边界；不安装 Fail2ban（高位端口 + 纯密钥认证下，Fail2ban 属纯资源浪费）。
2. **SSH 零密码高位加固**：
   - 默认 22 端口彻底切断（UFW 规则删除 + 端口热切双重保障）。
   - 迁移至高位端口 `ssh_port`（22122），杜绝盲扫打爆 auth.log。
   - 仅允许 Ed25519 纯密钥认证，关闭密码登录、空密码，限制 root 仅能密钥登录（`prohibit-password`）。
3. **SSH 端口热切换与全自动闭环**：
   - 执行时序：自适应探测高位端口（22122） → 开荒时临时放行 22 端口 → 原子部署公钥（主控公钥 + `extra_ssh_authorized_keys` 多设备密钥） → 修改 sshd 配置 → `wait_for` 验证新端口连通性 → `set_fact` 切换端口 → `reset_connection` 刷新长连接 → 自动调用 UFW 模块剥离 22 端口实现硬封闭环。
   - `site.yml` pre_task 先探测新端口是否可达，不可达则 fallback 到 22，保障白板开荒不锁死。
4. **自动安全补丁**：
   - 启用 `unattended-upgrades` 自动安装安全更新，归属 `infrastructure` role。

---

## 4. Roles 职责边界

- **`roles/security`**：访问控制层。负责 UFW 主机防火墙放行 + SSH 纯密钥高位 22122 硬化与 22 端口自动闭环硬封。
- **`roles/infrastructure`**：系统基建层。负责系统初始化（全量更新、基础工具、时区、别名、logrotate）、BBR 拥塞控制、Swap 虚拟内存、`unattended-upgrades` 自动安全补丁、Nginx 基础与 Stream SNI 分流骨架、DDNS 同步。
- **`roles/application`**：应用业务层。负责 Aria2 下载服务与 WebDAV 文件管理。
- **`roles/vpn`**：代理网络层。负责 Xray (VLESS+Reality) 部署与凭证分发。

---

开始任务前先读 @CONTEXT.md
