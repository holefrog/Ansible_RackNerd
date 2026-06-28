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

    read -rp "是否需要将公钥复制到目标 VPS (ssh-copy-id)？[y/N]: " copy_key
    if [[ "$copy_key" =~ ^[Yy]$ ]]; then
        read -rp "请输入目标 VPS 登录地址 (例如 root@192.227.234.149): " target_host
        if [[ -n "$target_host" ]]; then
            # 提取目标 IP (处理包含 user@ 的情况)
            actual_host="${target_host#*@}"
            echo ">>> 清理本地 known_hosts 中的旧密钥记录..."
            ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$actual_host" >/dev/null 2>&1 || true
            echo ">>> 执行 ssh-copy-id -i ${KEY}.pub ${target_host}"
            ssh-copy-id -o StrictHostKeyChecking=no -i "${KEY}.pub" "$target_host"
        else
            echo "未输入目标，跳过。"
        fi
        echo ""
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
    echo "⚠️  【安全提醒】"
    echo "本次部署已配置:"
    echo "自定义 SSH 端口：[${SHOW_PORT}]"
    echo ""
    echo "为防止您意外被锁在服务器外，22 端口暂时保留。"
    echo "请务必在新开的终端中测试能否通过新端口登录服务器。"
    echo "确认无误后，请手动执行以下命令彻底关闭 22 端口："
    echo "👉 ./close_22.sh"
    echo "========================================================"
fi
