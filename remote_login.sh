#!/usr/bin/env bash
# remote_login.sh - 多机版独立登录工具

set -euo pipefail

# ==========================================================
# 1. 准备工作
# ==========================================================
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR] $1${NC}" >&2; exit 1; }

# 检查输入参数
if [ $# -lt 1 ]; then
    echo -e "${GREEN}用法: $0 <主机名>${NC}"
    echo -e "可选主机: $(ls host_vars | tr '\n' ' ')"
    exit 1
fi

TARGET_HOST=$1
HOST_DIR="host_vars/$TARGET_HOST"

if [ ! -d "$HOST_DIR" ]; then
    error "未找到主机目录: $HOST_DIR"
fi

# ==========================================================
# 2. 崩溃追踪与清理 (Trap)
# ==========================================================
trap 'echo -ne "\e]110\a\e]111\a\033[0m"; echo -e "\n${GREEN}>>> 已安全断开 $TARGET_HOST${NC}"' EXIT

# 极简解析函数 (支持多行/多文件查找)
get_v() {
    local key=$1
    local file=$2
    # 匹配 key: value 格式，忽略缩进和注释
    awk -F ':[ \t]+' -v k="^[ \t]*$key$" '$1~k{v=$2;sub(/[ \t]*#.*/,"",v);gsub(/^[ \t]+|[ \t]+$|^"|"$|^'\''|'\''$/,"",v);print v;exit}' "$file"
}

# ==========================================================
# 3. 变量搜寻逻辑
# ==========================================================
VARS_FILE="$HOST_DIR/vars.yml"
SEC_FILE="$HOST_DIR/secrets.yml"

# 1. 获取连接地址 (优先从 vars.yml 读 domain，读不到则从 hosts.yml 读 ansible_host)
HOST=$(get_v "domain" "$VARS_FILE")
if [[ -z "$HOST" ]]; then
    HOST=$(get_v "$TARGET_HOST" "hosts.yml") # 简单处理：假设 hosts.yml 里主机名后面直接跟着 IP
    [[ -z "$HOST" ]] && HOST=$(get_v "ansible_host" "hosts.yml") # 或者精确查找
fi

# 2. 获取端口
PORT=$(get_v "ssh_port" "$VARS_FILE")

# 3. 获取认证信息
PASS=$(get_v "ansible_ssh_pass" "$SEC_FILE")
KEY_FILE=$(get_v "ansible_ssh_private_key_file" "$VARS_FILE")

# ==========================================================
# 4. 执行登录
# ==========================================================
if [[ -n "$KEY_FILE" && -f "$KEY_FILE" ]]; then
    chmod 600 "$KEY_FILE"
    SSH_CMD="ssh -i $KEY_FILE"
elif [[ -n "$PASS" ]]; then
    SSH_CMD="sshpass -p '$PASS' ssh"
else
    error "主机 $TARGET_HOST 未配置有效密钥或密码"
fi

echo -e "${GREEN}>>> 正在连接 $TARGET_HOST [$HOST] (端口: $PORT)...${NC}"

# 清理指纹
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$HOST" >/dev/null 2>&1 || true

# 激活配色并登入
echo -ne "\e]10;#39FF14\a\e]11;#000000\a"
$SSH_CMD -p "$PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$HOST"
