# 📜 Yattee 使用指南

本文档为 Ansible 自动化部署完成后的**使用操作指南**。所有服务端基础设施（Docker 容器、Nginx 反代、SSL 证书、DDNS）均由 Ansible 一键部署，无需手动配置。

---

## 📱 第一步：注册美区谷歌账号（带 2FA）

由于谷歌在 2026 年大幅强化了对网页端的风控，直接在电脑端注册极易卡死在手机号验证上。**使用安卓手机的系统设置层注册，能 100% 触发「跳过」按钮，是最可靠的方案。**

### 1. 安卓手机系统层注册（免强绑定非美区手机号）
1. **网络隔离：** 在安卓手机上打开网络工具，切换到 **美国（US）** 节点，并开启 **全局路由（Global）** 模式。
2. **切断网页：** 不要使用 Chrome。直接进入安卓手机的 **`Settings (系统设置)`** -> 找到 **`Google`** 或 **`Accounts (账户)`** -> 点击 **`Add account (添加账户)`** -> 选择 **Google**。
3. **开始创建：** 点击左下角 `Create account` -> 选择 `For my personal use`。
4. **填写资料：** 名字随意填，生日年份确保成年（填 2000 年以前，未成年账号会触发 YouTube API 的内容限制导致 Yattee 报错）。
5. **绕过验证码（关键点）：** 走到填写手机号的页面时，直接点击左下角的 **`Skip (跳过)`** 按钮。顺利绕过强制手机号强绑定，直接生成纯正的美区账号。

### 2. 开启 2FA 两步验证与生成 Yattee 专用密码
由于 `yattee-server` 部署在美国云端 VPS 上，其机房 IP 和你手机的注册 IP 异地。如果直接在 Yattee 后台输入主密码登录，有 90% 的概率触发谷歌安全报警而导致登录失败。**必须开启两步验证并使用"应用专用密码"降维打击风控。**

1. 账号注册成功后，在电脑或手机浏览器中登录该新账号，访问 **[https://myaccount.google.com](https://myaccount.google.com)**。
2. 在左侧/顶部菜单点击 **`Security (安全性)`** -> 往下划找到 **`How you sign in to Google（登录 Google 的方式）`** -> 点击 **`2-Step Verification (两步验证)`** 并将其开启。*（注：此处可以使用你的本地真实手机号接收一次性短信完成验证，仅用于两步验证保护，不会改变账号的美区归属国身份）*。
3. 两步验证开启后，你的美区账号即做好了万全准备，可以随时用来进行下一步的电视端授权了。（注意：此账号只需在你的个人电脑浏览器中保持登录即可，**不需要为它生成 16 位的 App Password**，因为全新的 TV OAuth2 协议采用的是无密码扫码/输入授权码模式）。

---

## 📺 第二步：绑定 OAuth2 绕过机房风控（电视端协议）

在 2024-2026 年，YouTube 针对 RackNerd 等机房 VPS 进行了严格的反爬风控，直接填入 Cookie 往往会被秒封并报出 `Sign in to confirm you’re not a bot` 错误。

为了彻底解决此问题，本 Ansible 部署在系统底层强制给 `yt-dlp` 注入了 `--oauth2` 参数，让服务器伪装成美区智能电视。具体授权步骤如下：

1. **触发授权流程：**
   - 访问 `https://yattee.yourdomain.com/admin`，输入管理员账密登录。
   - 进入左侧 **`Sites`（站点管理）** -> 找到 **YouTube** -> 点击 **Edit**。
   - 在底部随便输入一个 YouTube 视频链接（如 `https://www.youtube.com/watch?v=jNQXAC9IVRw`），点击 **`Test Credentials (测试凭证)`**。此时网页会进入加载状态（卡住是正常的）。

2. **获取电视端配对码：**
   - 马上在你的电脑上 SSH 登录到 VPS 终端，执行以下命令查看容器实时日志：
     ```bash
     docker logs -f yattee-server
     ```
   - 你会在日志中看到一行类似这样的谷歌官方电视配对提示：
     > `[youtube+oauth2] To give yt-dlp access to your account, go to https://www.google.com/device and enter code XXX-YYY-ZZZ`

3. **完成配对授权：**
   - 复制那串 8 位数的 `XXX-YYY-ZZZ` 代码。
   - 在电脑浏览器上（**确保该浏览器登录的是你准备好的带 2FA 的美区谷歌账号**）打开：**[https://www.google.com/device](https://www.google.com/device)**。
   - 输入代码，点击下一步。当谷歌提示正在申请授权 **"YouTube on TV"** 时，点击 **`Allow（允许）`**。
   - 回到 SSH 终端，看到日志输出 `OAuth2 authentication successful`，说明授权密钥已成功落盘。此后无限期免 Cookie 稳定抓取。按 `Ctrl + C` 退出日志。

---

## 📱 第三步：iPhone / macOS Yattee 客户端对接

1. 在 iPhone 上安装 **Yattee**（TestFlight 2.0 版或 App Store 正式版皆可）。
2. 进入 **`Settings (⚙️)`** -> **`Locations (位置)`** -> 点击底部 **`+ Add Location (添加位置)`**。
3. 在 **Address (地址)** 中填入你的专属后端地址：`https://yattee.yourdomain.com/`。
4. 保存并**选中该节点**。
5. 点击进入该 Location 详情，选择 **`+ Add Account (添加账号)`**，输入管理员账密。
6. 完成！直接锁屏关机，享受丝滑无广告的后台音频播放。

---

## 🔄 容器自动更新

由于 YouTube 网页端算法频繁改版，底层的 `yt-dlp` 解析组件需要定期更新。

Ansible 已部署了 **`yattee-update.timer`** 定时任务，**每周一凌晨 4:00** 自动执行 `git pull && docker compose up -d --build`，在不破坏落盘 OAuth2 凭证的前提下完成静默热更新。

如果遇到解析故障需要手动立即更新，SSH 登录 VPS 执行：

```bash
cd /opt/yattee-server
git pull && docker compose up -d --build
```
