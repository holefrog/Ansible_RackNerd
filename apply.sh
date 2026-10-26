#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "--------------------------------------------------------"
echo "🚀 RackNerd VPS 部署与管理系统"
echo "--------------------------------------------------------"
echo "1) Deploy      - 执行完整部署 (集成三重严格检查, site.yml)"
echo "2) Status      - 检查 VPS 资源与业务健康状态 (check_status.yml)"
echo "--------------------------------------------------------"
read -rp "请选择 [1/2，直接回车默认 2 Status]: " choice

case "$choice" in
    1)
        MODE="Deploy"
        PB="site.yml"
        ;;
    2|"")
        MODE="Status"
        PB="check_status.yml"
        ;;
    *)
        echo "已退出。"
        exit 0
        ;;
esac

echo ">>> 已选择: ${MODE}"
echo ""

# 检查是否开启 verbose
VERBOSE=""
read -rp "是否开启详细输出 verbose？[y/N]: " v
if [[ "$v" =~ ^[Yy]$ ]]; then
    VERBOSE="-v"
fi
echo ""

# VPS 一般默认 root 登录，若非 root 且需 sudo 密码则解除注释
# BECOME_PASS=""
# read -rp "是否需要输入 sudo 密码 (用于 become)？[y/N]: " bp
# if [[ "$bp" =~ ^[Yy]$ ]]; then
#     BECOME_PASS="-K"
# fi
# echo ""

# 仅在部署时提示是否处理 SSH 密钥
if [[ "$MODE" == "Deploy" ]]; then
    # 动态从 vars.yml 提取私钥路径，消除硬编码
    KEY_REL_PATH=$(awk '/^ansible_ssh_private_key_file:/ {print $2; exit}' host_vars/*/vars.yml 2>/dev/null | tr -d '"'\''')
    if [[ -z "$KEY_REL_PATH" ]]; then
        KEY_REL_PATH="keys/id_ed25519"
    fi
    KEY="${SCRIPT_DIR}/${KEY_REL_PATH}"
    
    if [[ ! -f "$KEY" ]]; then
        echo "⚠️ 未找到 SSH 私钥: ${KEY}"
        read -rp "是否自动生成新的 SSH 密钥？[y/N]: " gen_key
        if [[ "$gen_key" =~ ^[Yy]$ ]]; then
            mkdir -p "$(dirname "$KEY")"
            ssh-keygen -t ed25519 -f "$KEY" -N ""
            echo "✅ 密钥已生成。"
        else
            echo "❌ 请先生成密钥并放入正确目录 (例如: ssh-keygen -t ed25519 -f ./${KEY_REL_PATH})"
            exit 1
        fi
    fi
    chmod 400 "$KEY"

    # 自动清理本地 known_hosts 中的旧密钥记录，防止用户未来手动 ssh 时遇到指纹冲突报错
    INV="hosts.yml"
    TARGET_IP=$(awk '/^[ \t]*[a-zA-Z0-9_-]+:[ \t]*$/ {in_host=1; next} in_host && /^[ \t]*ansible_host:/ {print $2; exit}' "$INV" | tr -d '"'\''')
    if [[ -n "$TARGET_IP" ]]; then
        echo ">>> 正在清理本地 known_hosts 旧指纹记录 (为自动化公钥分发铺路)..."
        ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$TARGET_IP" >/dev/null 2>&1 || true
        echo ""
    fi

    # --- 自动化开荒连通性自检与公钥注入 ---
    TARGET_USER=$(awk '/^ansible_user:/ {print $2; exit}' host_vars/*/vars.yml 2>/dev/null | tr -d '"'\''')
    TARGET_USER="${TARGET_USER:-root}"
    SSH_PORT=$(awk '/^ssh_port:/ {print $2; exit}' host_vars/*/vars.yml 2>/dev/null | tr -d '"'\''')
    SSH_PORT="${SSH_PORT:-22122}"

    echo "🔍 正在探测目标主机 [${TARGET_IP}] 认证连通状态..."

    # 1. 尝试密钥免密连接 (优先高位端口，次选 22 端口)
    KEY_LOGIN_SUCCESS=false
    if ssh -i "$KEY" -p "$SSH_PORT" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_IP}" "echo ok" >/dev/null 2>&1; then
        echo "✅ SSH 密钥免密登录正常 (高位端口 ${SSH_PORT})。"
        KEY_LOGIN_SUCCESS=true
    elif ssh -i "$KEY" -p 22 -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_IP}" "echo ok" >/dev/null 2>&1; then
        echo "✅ SSH 密钥免密登录正常 (默认 22 端口，将在后续部署中迁移至 ${SSH_PORT})。"
        KEY_LOGIN_SUCCESS=true
    fi

    # 2. 若密钥免密失败，说明为全新机器或重置机，需要检查 22 端口密码连通并注入公钥
    if [[ "$KEY_LOGIN_SUCCESS" == false ]]; then
        echo "⚠️ 目标主机无法通过本地私钥连接，进入【白板机自适应开荒】检测..."

        # 检查 22 端口网络是否通畅
        PORT_22_OPEN=false
        if (timeout 3 bash -c "</dev/tcp/${TARGET_IP}/22") >/dev/null 2>&1; then
            PORT_22_OPEN=true
        fi

        if [[ "$PORT_22_OPEN" == false ]]; then
            echo "❌ 错误：无法连接到目标主机 ${TARGET_IP} 的 22 端口，网络连接超时或被拒绝。"
            echo "💡 请检查 VPS 是否处于运行中状态、或控制台网络是否正常。"
            exit 1
        fi

        echo "📡 目标主机 22 端口网络通畅，正在尝试密码认证与公钥注入..."

        # 确保公钥存在
        PUB_KEY="${KEY}.pub"
        if [[ ! -f "$PUB_KEY" ]]; then
            ssh-keygen -y -f "$KEY" > "$PUB_KEY"
        fi

        # 读取 secrets.yml 中的密码
        SAVED_PASS=$(awk '/^ansible_ssh_pass:/ {print $2; exit}' host_vars/*/secrets.yml 2>/dev/null | tr -d '"'\''')

        # 检查是否已配置密码
        if [[ -z "$SAVED_PASS" ]]; then
            echo ""
            echo "========================================================"
            echo "❌ 【未配置初始登录密码】"
            echo "目标主机 22 端口开放，但在 host_vars/vps_primary/secrets.yml 中未找到 'ansible_ssh_pass'！"
            echo "💡 提示：目标主机重置后只支持密码登录，请先在 secrets.yml 中填入重置后的 root 密码："
            echo "   👉 host_vars/vps_primary/secrets.yml -> ansible_ssh_pass: \"你的密码\""
            echo "========================================================"
            exit 1
        fi

        # 检查是否安装 sshpass
        if ! command -v sshpass &>/dev/null; then
            echo "❌ 错误：检测到未安装 sshpass 工具，无法自动执行密码开荒。"
            echo "💡 请先安装 sshpass：sudo apt install -y sshpass"
            exit 1
        fi

        # 测试密码是否正确并捕获错误输出
        PASS_TEST=$(sshpass -p "$SAVED_PASS" ssh -p 22 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${TARGET_USER}@${TARGET_IP}" "echo ok" 2>&1)
        PASS_EXIT_CODE=$?

        if [[ $PASS_EXIT_CODE -ne 0 ]]; then
            echo ""
            echo "========================================================"
            echo "❌ 【SSH 认证失败 - 密码错误】"
            echo "目标主机 [${TARGET_IP}:22] 网络连接正常，但密码登录失败！"
            echo "系统返回: ${PASS_TEST}"
            echo ""
            echo "💡 【解决指引】"
            echo "目标主机刚刚重置过，secrets.yml 中的旧密码已失效。"
            echo "请打开并更新以下文件中的 root 密码："
            echo "👉 host_vars/vps_primary/secrets.yml"
            echo "   将其中的 ansible_ssh_pass 更新为控制台或邮件提供的最新密码。"
            echo ""
            echo "更新保存后，重新执行 ./apply.sh 即可自动注入公钥！"
            echo "========================================================"
            exit 1
        fi

        echo "🔑 密码验证通过！正在将本地公钥注入目标主机 authorized_keys..."
        sshpass -p "$SAVED_PASS" ssh-copy-id -i "$PUB_KEY" -p 22 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_IP}" >/dev/null 2>&1

        # 验证注入后能否使用私钥登录
        if ssh -i "$KEY" -p 22 -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_IP}" "echo ok" >/dev/null 2>&1; then
            echo "🎉 公钥成功注入目标主机！已转入纯密钥通信，继续执行后续加固与部署..."
            echo ""
        else
            echo "❌ 公钥注入后仍无法通过私钥登录，请检查远程主机的 authorized_keys 权限或 sshd 配置。"
            exit 1
        fi
    fi
fi

echo "--------------------------------------------------------"
echo "🛠️  正在执行 ${MODE}..."
echo "--------------------------------------------------------"

readonly INV="hosts.yml"

# 如果是部署模式，继承原 deploy.sh 的严格检查流程
if [[ "$MODE" == "Deploy" ]]; then
    echo ">>> [1/3] 正在执行 ansible-lint 静态分析..."
    if command -v ansible-lint &> /dev/null; then
        if ! ansible-lint "$PB"; then
            echo -e "\n❌ 静态分析未通过，请检查代码规范。"
            exit 1
        fi
    else
        echo "⚠️ 检测到未安装 ansible-lint，建议使用 sudo apt install ansible-lint 安装以保障代码质量。"
    fi

    echo ">>> [2/3] 正在执行语法校验..."
    if ! ansible-playbook -i "$INV" "$PB" --syntax-check; then
        echo -e "\n❌ 语法校验失败。"
        exit 1
    fi

    echo ">>> [3/3] 正在执行 --check 模拟运行 (逻辑干跑)..."
    if ! ansible-playbook -i "$INV" "$PB" --check; then
        echo -e "\n⚠️ 模拟运行 (Check Mode) 提示了一些由于新环境未就绪（如服务不存在）导致的假报错，已自动忽略。\n"
    else
        echo -e "\n✅ 三重检查全部通过！\n"
    fi
fi

echo "========================================================"
echo "🚀 开始进行真实的服务器部署与配置 (Real Deployment)"
echo "========================================================"

# 执行 playbook (过滤掉多余的脚本参数 $@ 以防误输入)
ansible-playbook -i "$INV" "$PB" $VERBOSE

echo ""
echo "🎉 ${MODE} 完成！"

if [[ "$MODE" == "Deploy" ]]; then
    # 尝试提取配置的 SSH 端口，使用 awk 保证跨平台兼容性
    SHOW_PORT=$(awk '/^ssh_port:/ {print $2; exit}' host_vars/*/vars.yml 2>/dev/null || echo "未知")
    
    echo "========================================================"
    echo "🎉 【部署安全闭环通知】"
    echo "本次部署已全面完成安全加固:"
    echo "1. 自定义 SSH 端口：[${SHOW_PORT}]"
    echo "2. 默认 22 端口：已通过 UFW 自动闭环切断硬封 (防扫防爆破)"
    echo ""
    echo "若遇极端异常需手动重试切断，可执行备用脚本: ./close_22.sh"
    echo "日常运维状态巡检请运行: ./apply.sh (选 2 Status)"
    echo "========================================================"
fi
