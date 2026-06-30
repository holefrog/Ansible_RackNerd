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
3. 两步验证开启后，直接在浏览器地址栏输入并访问专用直达链接：**[https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)**。
4. 在 **App name** 中输入自定义名称（例如：`Yattee Server`），点击 **`Create (创建)`**。
5. 屏幕上会弹出一个由 **16 位英文字母组成的黄色背景专用密码**。**请立刻复制并妥善保存它**（弹窗关闭后无法再次查看）。后续在登录 Yattee 后台时，**使用该 16 位密钥代替你原本的谷歌主密码**，即可 100% 免异地验证直通登录。

---

## 📺 第二步：绑定 OAuth2（电视端协议，一劳永逸）

通过将服务器伪装成美区智能电视，获取无限期有效的 Refresh Token，从此不再受短期网页 Cookie 丢状态的折磨。

1. 打开电脑浏览器，访问 `https://yatee.holefrog.dynamic-dns.net/admin`，输入 `vars.yml` 和 `secrets.yml` 中配置的管理员账号密码。
2. 进入 **`Sites`（站点管理）** -> 找到 **YouTube** -> 点击 **Configure**。
3. 将 **Authentication Method**（验证方式）从默认的 *Cookies* 切换为 **`OAuth2`** 并保存。
4. **获取授权码：** SSH 登录 VPS，执行以下命令实时查看容器运行日志：
   ```bash
   docker logs -f yattee-server
   ```
5. 终端日志中会滚出一行谷歌官方电视配对提示：
   > `[youtube+oauth2] To give yt-dlp access to your account, go to https://www.google.com/device and enter code XXX-YYY-ZZZ`
6. **进行配对：** 复制那串 8 位数的 `XXX-YYY-ZZZ` 代码。在电脑浏览器上（**确保浏览器登录的是你准备好的带 2FA 的美区谷歌账号**）打开：**[https://www.google.com/device](https://www.google.com/device)**。
7. 输入代码，点击下一步。当谷歌提示正在申请授权 **"YouTube on TV"** 时，点击 **`Allow（允许）`**。
8. 回到 SSH 终端，看到日志输出 `OAuth2 authentication successful`，说明密钥已安全落盘并持久化。按 `Ctrl + C` 退出日志跟踪。

---

## 📱 第三步：iPhone / macOS Yattee 客户端对接

1. 在 iPhone 上安装 **Yattee**（TestFlight 2.0 版或 App Store 正式版皆可）。
2. 进入 **`Settings (⚙️)`** -> **`Locations (位置)`** -> 点击底部 **`+ Add Location (添加位置)`**。
3. 在 **Address (地址)** 中填入你的专属后端地址：`https://yatee.holefrog.dynamic-dns.net/`。
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
