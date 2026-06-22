# Ansible_RackNerd

基于 Ansible 的多节点 VPS 自动化运维方案。核心思路是 **“主机差异化”**、**“零硬编码”** 与 **“安全闭环”**，适配 RackNerd 等基于 DNF/RPM 的 Linux 系统。

## 核心逻辑

* **多机架构设计**：完全弃用 `group_vars`，通过 `host_vars/主机名/` 实现多台 VPS 的精准控制，支持不同域名、端口及密钥配置。
* **WebDAV 管理增强**：通过 Nginx `add_after_body` 注入自定义脚本，实现网页端图标预览及**路径纠偏后的直接删除**功能。
* **V2Ray 自动化闭环**：一键部署并同步生成 JSON、vmess 链接及二维码，修复了 Shell 变量引号导致的 JSON 损坏风险。
* **SSL 自动化 (零竞态)**：内置 Certbot 逻辑，申请证书前自动关停 Nginx 以释放 80 端口，解决首次部署的端口冲突。
* **三重严格校验**：`deploy.sh` 集成 `ansible-lint` 静态分析、语法校验及 `--check` 逻辑干跑，从根源杜绝变量名带空格或私钥误读导致的生产崩溃。

## 项目组织

````text
├── ansible.cfg               # 性能优化配置 (Pipelining, ControlMaster)
├── check_status.yml          # VPS 资源与业务健康看板
├── deploy.sh                 # 自动化部署脚本 (含严格检查逻辑)
├── git_push_all.sh           # Git 快速提交脚本
├── hosts.yml                 # 主机清单 (按业务组划分)
├── host_vars                 # 主机级变量目录
│   ├── vps_primary
│   │   ├── secrets.yml       # 敏感信息 (密码哈希、UUID 等)
│   │   └── vars.yml          # 第一台主机基础配置
│   └── vps_secondary
│       ├── secrets.yml
│       └── vars.yml
├── keys                      # 私钥目录 (不参与变量解析，更安全)
│   ├── vps_primary_key       # 第一台主机的私钥
│   ├── vps_primary_key.pub
│   ├── vps_secondary_key
│   └── vps_secondary_key.pub
├── README.md                 # 项目说明文档
├── remote_login.sh           # 自动化 SSH 一键登录脚本
├── roles                     # 功能角色目录
│   ├── application           # 应用层 (Aria2 安装与降权运行)
│   ├── infrastructure        # 基础层 (Nginx, WebDAV, DDNS, 系统优化)
│   ├── security              # 安全层 (SSH 密钥分发, 防火墙, Fail2ban)
│   └── vpn                   # 代理层 (V2Ray 安装与订阅分发)
└── site.yml                  # 部署总入口 (挂载所有 Roles)
