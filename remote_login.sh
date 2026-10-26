#!/usr/bin/env bash
# remote_login.sh - 单机免密快捷登录工具 (默认直连 vps_primary)

set -euo pipefail

# ==========================================================
# 1. 准备工作
# ==========================================================
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR] $1${NC}" >&2; exit 1; }

# 默认指向唯一单机 vps_primary (无需手动输入参数)
TARGET_HOST="${1:-vps_primary}"
HOST_DIR="host_vars/$TARGET_HOST"

if [ ! -d "$HOST_DIR" ]; then
    # 若指定的 host 不存在，自动探测 host_vars 下的第一个主机
    DETECTED_HOST=$(ls -1 host_vars 2>/dev/null | head -n 1)
    if [[ -n "$DETECTED_HOST" && -d "host_vars/$DETECTED_HOST" ]]; then
        TARGET_HOST="$DETECTED_HOST"
        HOST_DIR="host_vars/$TARGET_HOST"
    else
        error "未找到主机目录: $HOST_DIR"
    fi
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

# 1. 获取连接地址 (优先使用 hosts.yml 的真实公网 IP，解耦 DNS 依赖；读不到回退 vars.yml domain)
HOST=$(awk -v target="^[ \t]*${TARGET_HOST}:[ \t]*$" '$0 ~ target {in_host=1; next} in_host && /^[ \t]*ansible_host:/ {print $2; exit}' hosts.yml | tr -d '"'\''')
if [[ -z "$HOST" ]]; then
    HOST=$(get_v "domain" "$VARS_FILE")
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

# 清理指纹 (同时清理默认端口和自定义端口的记录)
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$HOST" >/dev/null 2>&1 || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[$HOST]:$PORT" >/dev/null 2>&1 || true

# 激活配色并登入 (添加 IdentitiesOnly=yes 避免 ssh-agent 多密钥导致认证超限)
echo -ne "\e]10;#39FF14\a\e]11;#000000\a"
$SSH_CMD -p "$PORT" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$HOST"

