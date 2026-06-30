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

### 2. 开启 2FA 两步验证（账号保护）
在使用 Cookie 授权方案时，你的密码和账号不会直接在服务器端暴露，极大降低了被谷歌风控的概率。但为了进一步保障账号安全，强烈建议开启两步验证。

1. 账号注册成功后，在电脑或手机浏览器中登录该新账号，访问 **[https://myaccount.google.com](https://myaccount.google.com)**。
2. 在左侧/顶部菜单点击 **`Security (安全性)`** -> 往下划找到 **`How you sign in to Google（登录 Google 的方式）`** -> 点击 **`2-Step Verification (两步验证)`** 并将其开启。*（注：此处可以使用你的本地真实手机号接收一次性短信完成验证，仅用于两步验证保护，不会改变账号的美区归属国身份）*。
3. 两步验证开启后，你的美区账号即做好了万全准备。此账号只需在你的个人电脑浏览器中保持登录即可，后续我们将通过提取本地浏览器 Cookie 的方式进行凭证授权。

---

## 📺 第二步：配置 YouTube 身份凭证 (Cookies)

在 2024-2026 年，YouTube 针对 RackNerd 等机房 VPS 进行了严格的反爬风控。如果后台不填入任何身份凭证，在提取视频时必定会报出 `Sign in to confirm you’re not a bot` 的错误。

由于我们根本就不能用 OAuth2，目前最稳定绕过风控的方法仍然是向后端注入真实的浏览器 Cookies。

1. **获取 Cookies（零 IP 跳跃法）**：
   因为账号注册在美国且 VPS 在美国，如果直接在其它国家提取 Cookie 导入机房，100% 会触发 `Sign in to confirm you're not a bot`（Google 会检测到“家宽登录 -> 机房请求”的异地瞬移）。
   因此，**一定要连接 VPS 上的 Xray 后，使用代理启动纯净的 Chrome，登录 YouTube 再导出 Cookie，在 VPS 上才能正常使用！**

   **① 前提条件：确保你的系统安装了解密模块（Linux 系统下提取时）**
   Chrome 的核心登录 Cookie 是加密存放的，如果没有 `secretstorage`，yt-dlp 提取到的将全是无用的空壳。
   ```bash
   sudo apt update && sudo apt install -y python3-secretstorage
   ```

   **② 第一步：连接本地 VPN 隧道**
   你需要使用代理软件（如 Hiddify）连接到你的 VPS。
   
   **【Hiddify 使用简介与最新配置方法】**
   Hiddify 是一款支持全平台的现代化代理客户端，能够完美解析我们部署的 Xray (VLESS/Reality) 节点。
   - **下载地址**：请访问官方 GitHub Releases [hiddify/hiddify-app](https://github.com/hiddify/hiddify-app/releases) 页面。
     - Windows 用户请下载 `Hiddify-Windows-Setup-x64.exe` 等安装包。
     - Linux 用户请下载 `.AppImage` 或 `.deb` 格式文件。
   - **最新使用方法**：
     1. 安装并打开 Hiddify 客户端。
     2. 复制你 VPS 上的 Xray 节点链接（即 `vless://...` 开头的那串代码）。
     3. 点击 Hiddify 主界面的 **“+” (添加)** 按钮，选择 **“从剪贴板添加 (Add from Clipboard)”** 导入节点。
     4. 在主界面或设置中，将“路由模式”切换为 **全局 (Global)**（这对成功欺骗 Google 风控极其关键）。
     5. 点击中央的 **大圆圈按钮** 连接到你的 VPS。
     6. 连接成功后，Hiddify 默认会在本地开启 SOCKS5 代理，端口为 `12334`（可在 设置 -> 高级设置 中确认该端口号）。

   **③ 第二步：启动纯净的“代理专属 Chrome”**
   千万不要用你的日常 Chrome，也不要用隐身模式（隐身模式无法落盘保存 Cookie）。
   在终端运行以下命令，启动一个**完全隔离且强制走 VPS 代理**的全新 Chrome：
   ```bash
   google-chrome --proxy-server="socks5://127.0.0.1:12334" --user-data-dir="$HOME/chrome_yattee"
   ```
   
   在弹出的新浏览器中，正常登录你的 YouTube 账号。登录完成后，**务必彻底关闭该 Chrome 窗口**（释放数据库文件锁）。

   **④ 第三步：代理环境下的精准提取**
   执行最终的 yt-dlp 提取命令。该命令同样强制走代理，并精确指定刚才那个隔离的 Chrome 配置文件夹：
   ```bash
   yt-dlp --proxy "socks5://127.0.0.1:12334" --cookies-from-browser "chrome:$HOME/chrome_yattee" --cookies cookies.txt "https://www.youtube.com/watch?v=jNQXAC9IVRw" --skip-download ; echo "# Netscape HTTP Cookie File" > ~/Temp/yt-cookies.txt ; grep "youtube" cookies.txt >> ~/Temp/yt-cookies.txt
   ```
   *(注：如果命令最后报错 `No video formats found`，直接无视它，因为我们需要的 Cookie 已经在报错前被成功导出了！)*

   只要命令执行后没有弹出机器人验证，说明 Cookie 已经成功经受住了机房 IP 的风控考验。打开 `~/Temp/yt-cookies.txt`，将其中的全部内容复制准备粘贴。

2. **填入 Yattee 后台**：
   - 访问 `https://yattee.yourdomain.com/admin`，输入管理员账密登录。
   - 进入左侧 **`Sites`（站点管理）** -> 找到 **YouTube** -> 点击 **Edit**。
   - 验证方式保持为 **`Cookies`**。
   - 将刚才导出的 Cookie 文本粘贴到下方的输入框中。
   - 点击 **`Save (保存)`**。
   - 在底部随便输入一个 YouTube 视频链接（如 `https://www.youtube.com/watch?v=jNQXAC9IVRw`），点击 **`Test Credentials (测试凭证)`**。只要不再报错 bot，即代表授权成功！

3. *注意：如果未来在使用 Yattee 时再次出现提取失败或无法播放，说明 Cookie 已过期，请重复上述任一步骤重新获取并覆盖。*

---

## 📱 第三步：iPhone Yattee 客户端对接

1. **在 iPhone 上安装 Yattee**：
   - 先在 App Store 下载 **TestFlight**。
   - 然后使用浏览器打开链接 `https://testflight.apple.com/join/jTWDHuZE`。
   - 页面会自动跳转到 TestFlight，接受邀请并下载最新版本的 Yattee。
2. 进入 **`Settings (⚙️)`** -> **`Sources (源)`** -> 点击底部 **`+ Add Remote Server (添加源)`**。
3. 在 **Address (地址)** 中填入你的专属后端地址：`https://yattee.yourdomain.com/`。
4. 点击下方的 **`Detect (检测)`**，检测成功后会要求输入账号密码（例如 `admin`/`admin`）。
5. 保存后，就可以在首页使用新增加的 Source 来搜索和播放了。

---

## 🔄 容器自动更新

由于 YouTube 网页端算法频繁改版，底层的 `yt-dlp` 解析组件需要定期更新。

Ansible 已部署了 **`yattee-update.timer`** 定时任务，**每周一凌晨 4:00** 自动执行 `git pull && docker compose up -d --build`，在不破坏落盘 Cookie 凭证的前提下完成静默热更新。

如果遇到解析故障需要手动立即更新，SSH 登录 VPS 执行：

```bash
cd /opt/yattee-server
git pull && docker compose up -d --build
```

## 🛠️ 排障与运行日志

如果在使用过程中遇到视频无法播放、或者想确认 Invidious 代理是否正常接管了流量，可以通过实时查看容器日志来排查问题。SSH 登录 VPS 后执行：

```bash
docker logs -f yattee-server
```

*(使用 `Ctrl + C` 可以退出日志实时查看模式)*

