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

## 📺 第二步：配置 YouTube 身份凭证 (Cookies)

在 2024-2026 年，YouTube 针对 RackNerd 等机房 VPS 进行了严格的反爬风控。如果后台不填入任何身份凭证，在提取视频时必定会报出 `Sign in to confirm you’re not a bot` 的错误。

由于原生 `yt-dlp` 已不再支持直接通过参数开启 OAuth2（该功能原为已失效的第三方插件），我们目前最稳定绕过风控的方法仍然是向后端注入真实的浏览器 Cookies。

1. **获取 Cookies**：
   - 确保你在电脑的浏览器（推荐 Firefox 或 Chrome）中已登录美区 YouTube 账号。
   - **方法 A（原生极客法，推荐）**：如果你电脑上安装了 `yt-dlp`，可以直接在你的本地终端运行以下命令，将 Firefox 的 Cookie 提取并保存为文本文件：
     ```bash
     yt-dlp --cookies-from-browser firefox --cookies cookies.txt
     ```
     *(如果用的是 Chrome，将 `firefox` 换成 `chrome` 即可。生成后用文本编辑器打开 `cookies.txt` 并复制全部内容)*
   - **方法 B（浏览器插件法）**：安装插件 [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/ccpbcjlkhojgfhdkfgmhhgbfhbfiaepj)，在 YouTube 页面点击导出为 Netscape 格式文本。

2. **填入 Yattee 后台**：
   - 访问 `https://yattee.yourdomain.com/admin`，输入管理员账密登录。
   - 进入左侧 **`Sites`（站点管理）** -> 找到 **YouTube** -> 点击 **Edit**。
   - 验证方式保持为 **`Cookies`**。
   - 将刚才导出的 `cookies.txt` 全部文本内容粘贴到下方的输入框中。
   - 点击 **`Save (保存)`**。
   - 在底部随便输入一个 YouTube 视频链接（如 `https://www.youtube.com/watch?v=jNQXAC9IVRw`），点击 **`Test Credentials (测试凭证)`**。只要不再报错 bot，即代表授权成功！

3. *注意：YouTube 的 Cookie 存在有效期。为了最大程度延长寿命，导出 Cookie 后请直接关闭该浏览器的无痕窗口，**绝对不要点击“退出登录”**。如果未来再次出现提取失败，请重复此步骤更新 Cookie。*

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
