#!/bin/bash

# --- 1. 配置提取 ---
# 消除硬编码：支持传参，默认提取 hosts.yml 中的第一个主机名
if [ -n "${1:-}" ]; then
    TARGET="$1"
else
    TARGET=$(awk '/^[a-zA-Z0-9_-]+:/ && !/all:/ {print $1; exit}' hosts.yml | tr -d ':')
    [[ -z "$TARGET" ]] && TARGET="vps_primary"
fi
VAR_FILE="host_vars/${TARGET}/vars.yml"

if [ ! -f "$VAR_FILE" ]; then
    echo "❌ 错误：找不到变量文件 $VAR_FILE"
    exit 1
fi

# 从 hosts.yml 提取 IP，从 vars.yml 提取其他连接参数
IP=$(grep -A 2 "${TARGET}:" hosts.yml | grep ansible_host | awk '{print $2}')
NEW_PORT=$(grep "ssh_port:" "$VAR_FILE" | awk '{print $2}')
KEY_PATH=$(grep "ansible_ssh_private_key_file:" "$VAR_FILE" | awk '{print $2}' | tr -d '"')

echo "--------------------------------------------------------"
echo "🚀 准备连接服务器执行 [安全锁门] 操作..."
echo "📍 目标地址: ${IP}"
echo "🔌 尝试端口: ${NEW_PORT}"
echo "🔑 使用密钥: ${KEY_PATH}"
echo "--------------------------------------------------------"

# --- 2. 连通性预检 ---
echo "⏳ 正在通过新端口测试 SSH 握手..."

# 改进：捕获标准错误输出 (2>&1) 以获取详细错误
SSH_ERROR=$(ssh -i "${KEY_PATH}" -p "${NEW_PORT}" -o ConnectTimeout=5 -o BatchMode=yes "root@${IP}" "exit" 2>&1)
SSH_STATUS=$?

if [ $SSH_STATUS -eq 0 ]; then
    echo "✅ 握手成功！新端口 ${NEW_PORT} 已就绪。"
    echo "🛠️  正在调用 Ansible 执行防火墙指令..."
    
    # 执行 Ansible CLI 指令关闭 22 端口
    ansible "${TARGET}" -m firewalld -a "port=22/tcp state=disabled permanent=true immediate=true" \
        --become -e "ansible_port=${NEW_PORT}"

    ansible "${TARGET}" -m firewalld -a "service=ssh state=disabled permanent=true immediate=true" \
        --become -e "ansible_port=${NEW_PORT}"

    echo -e "\n🎉 任务成功完成！22 端口已彻底关闭。"
else
    # 打印详细的错误信息
    echo -e "\n❌ 无法通过端口 ${NEW_PORT} 连接到服务器！"
    echo "🔴 系统返回详情: ${SSH_ERROR}"
    
    # 针对常见错误给出更易读的提示
    if [[ "$SSH_ERROR" == *"Connection refused"* ]]; then
        echo "💡 提示：连接被拒绝。这通常意味着新端口上没有服务在监听，或者防火墙尚未放行该端口。"
    elif [[ "$SSH_ERROR" == *"Connection timed out"* ]]; then
        echo "💡 提示：连接超时。请检查安全组或网络路由是否允许该端口流量。"
    elif [[ "$SSH_ERROR" == *"Permission denied"* ]]; then
        echo "💡 提示：权限拒绝。请确认密钥文件权限或 SSH 登录用户名是否正确。"
    fi

    echo -e "\n⚠️  为了防止自锁，已终止 [关闭 22 端口] 的操作。"
    exit 1
fi
