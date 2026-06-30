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

由于原生 `yt-dlp` 已不再支持直接通过参数开启 OAuth2（该功能原为已失效的第三方插件），我们目前最稳定绕过风控的方法仍然是向后端注入真实的浏览器 Cookies。

1. **获取 Cookies**：
   - 🚨 **核心防封锁前提（极其重要）：在开始提取之前，请务必在你的电脑上全程开启全局代理，并连接美国节点（强烈建议直接连接你刚搭建好的本机 VPS Xray 节点）！** 这样能保证 Cookie 诞生的 IP 与服务端 `yt-dlp` 最终使用的 IP 完全一致（跳跃距离为 0），极大降低被 Google 判定为“异地盗用”而秒封的概率。
   - **方法 A（原生命令行法，推荐）**：如果你电脑上安装了 `yt-dlp`，可直接在本地终端提取。
     - **注意：必须使用普通窗口登录**（无痕模式的 Cookie 只在内存中，提取不到）。
     - 在终端运行以下命令，提取对应的浏览器 Cookie 并**仅过滤出 YouTube 的数据**保存：
       
       **如果你使用的是 Chrome 浏览器：**
       ```bash
       yt-dlp --cookies-from-browser chrome --cookies cookies.txt "https://www.youtube.com/watch?v=jNQXAC9IVRw" --skip-download ; echo "# Netscape HTTP Cookie File" > ~/Temp/yt-cookies.txt ; grep "youtube" cookies.txt >> ~/Temp/yt-cookies.txt
       ```

       **如果你使用的是 Firefox 浏览器：**
       ```bash
       yt-dlp --cookies-from-browser firefox --cookies cookies.txt "https://www.youtube.com/watch?v=jNQXAC9IVRw" --skip-download ; echo "# Netscape HTTP Cookie File" > ~/Temp/yt-cookies.txt ; grep "youtube" cookies.txt >> ~/Temp/yt-cookies.txt
       ```

       *(如果在执行时终端报错 `No video formats found!`，**完全不用理会**！Cookie 在报错前就已经成功提取到了。用文本编辑器打开 `~/Temp/yt-cookies.txt`，复制其全部内容)*
     - **延长寿命秘诀**：提取完成后，千万不要在网页点“退出登录”。直接去浏览器的设置里，手动清除 YouTube.com 的站点数据。这样本地去除了登录态，但远端 Cookie 依然存活！

   - **方法 B（浏览器插件法）**：
     - **注意：极力推荐使用无痕/隐私窗口登录**（需在扩展设置里允许该插件在隐私模式下运行）。
     - 安装插件 [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/ccpbcjlkhojgfhdkfgmhhgbfhbfiaepj)，在 YouTube 页面点击导出为 Netscape 格式文本。
     - **延长寿命秘诀**：导出文本后，**绝对不要点击“退出登录”**，直接关闭无痕窗口即可。

2. **填入 Yattee 后台**：
   - 访问 `https://yattee.yourdomain.com/admin`，输入管理员账密登录。
   - 进入左侧 **`Sites`（站点管理）** -> 找到 **YouTube** -> 点击 **Edit**。
   - 验证方式保持为 **`Cookies`**。
   - 将刚才导出的 Cookie 文本粘贴到下方的输入框中。
   - 点击 **`Save (保存)`**。
   - 在底部随便输入一个 YouTube 视频链接（如 `https://www.youtube.com/watch?v=jNQXAC9IVRw`），点击 **`Test Credentials (测试凭证)`**。只要不再报错 bot，即代表授权成功！

3. *注意：如果未来在使用 Yattee 时再次出现提取失败或无法播放，说明 Cookie 已过期，请重复上述任一步骤重新获取并覆盖。*

---

## 📱 终极防封方案：Yattee 客户端“前后端分离”玩法

如果你的机房 IP 彻底被 YouTube 拉黑，无论怎么贴 Cookie 都死活报错，**千万不要在服务端死磕了**！因为在 2026 年，各大公共 Invidious 节点为了自保，已经**全线拉黑了来自机房 IP 的 API 请求（全部报 401 或 403 错误）**。

Yattee 作为顶级播放器，早就为你准备了终极绝招：**数据库与视频流分离**。
你的自建服务器（被封的 IP）只用来存**订阅、播放历史、账号数据**。
真正的视频解析，全部交给你手机本地的网络（家庭宽带/干净梯子）直连海外公共 Piped 节点！

### 客户端终极配置步骤（针对 Yattee 2 最新版）：

1. **清空服务端烂摊子：** 如果你改过 `.env` 里的 `INVIDIOUS_INSTANCE_URL`，请删掉那行，重启容器，让服务端保持最原始的状态。Yattee 后台的 Cookie 爱填不填，不用管它了。
2. **在 iPhone/Mac 上打开 Yattee 客户端。**
3. **添加公共播放流源（用于提取视频）：**
   - 找到并进入 **`Sources (源)`** 设置界面。
   - 点击 **`Add (添加)`** -> **`Remote Server (远程服务器)`**。
   - 填入最稳定的公共 Piped 节点地址：`https://pipedapi.kavin.rocks` （或任何你喜欢的 Piped/Invidious 节点）。
   - 将其设置为默认/主要播放源。
4. **添加你的私有数据库（用于账号同步）：**
   - 再次点击 **`Add (添加)`** -> **`Remote Server (远程服务器)`**。
   - 填入你自己的专属后端地址：`https://yattee.yourdomain.com/`，保存。
   - 点击刚刚添加的这个专属服务器，输入你的管理员账密进行登录。
5. **起飞！** 只要你在自己的服务器上保持登录，Yattee 2 会非常智能地处理：你去搜索或点击视频时，它会自动用你手机当前干净的 IP 连接公共节点提取视频；同时把播放进度和订阅数据默默存回你的自建服务器里。完美实现“流媒体解析”与“隐私数据库”的分离！
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

---

## 🏆 终极绝招：如何为“新账号”提取免封锁 Cookie（零 IP 跳跃法）

如果你非要使用一个**毫无历史权重的新注册 Google 账号**，在直接导入机房 IP 部署的 yt-dlp 时，100% 会触发 `Sign in to confirm you're not a bot`（甚至直接作废你的 Cookie）。

这是因为 Google 风控检测到了“家宽登录 -> 机房请求”的异地瞬移。
为了打破这个魔咒，我们需要执行**“零 IP 跳跃法”**：强制让 Chrome 浏览器和 yt-dlp 都在你的 VPS 机房 IP 环境下运行！

### 核心步骤总结（Linux 终端演示）：

**前提条件：确保你的系统安装了解密模块**
Chrome 的核心登录 Cookie 是加密存放的，如果没有 `secretstorage`，yt-dlp 提取到的将全是无用的空壳。
```bash
sudo apt update && sudo apt install -y python3-secretstorage
```

**第一步：连接本地 VPN 隧道**
确保你的代理软件（如 Hiddify）已连接到你的 VPS，并确认了本地开放的 SOCKS5 代理端口（例如 Hiddify 默认的 `12334`）。

**第二步：启动纯净的“代理专属 Chrome”**
千万不要用你的日常 Chrome，也不要用隐身模式（隐身模式无法落盘保存 Cookie）。
在终端运行以下命令，启动一个**完全隔离且强制走 VPS 代理**的全新 Chrome：
```bash
google-chrome --proxy-server="socks5://127.0.0.1:12334" --user-data-dir="$HOME/chrome_yattee"
```
*在弹出的新浏览器中，正常登录你的 YouTube 新账号。登录完成后，**务必彻底关闭该 Chrome 窗口**（释放数据库文件锁）。*

**第三步：代理环境下的精准提取**
执行最终的 yt-dlp 提取命令。该命令同样强制走代理，并精确指定刚才那个隔离的 Chrome 配置文件夹：
```bash
yt-dlp --proxy "socks5://127.0.0.1:12334" --cookies-from-browser "chrome:$HOME/chrome_yattee" --cookies cookies.txt "https://www.youtube.com/watch?v=jNQXAC9IVRw" --skip-download ; echo "# Netscape HTTP Cookie File" > ~/Temp/yt-cookies.txt ; grep "youtube" cookies.txt >> ~/Temp/yt-cookies.txt
```

**第四步：大功告成**
只要命令执行后**没有**弹出 `Sign in to confirm you're not a bot`，说明 Cookie 已经成功经受住了机房 IP 的风控考验！
打开 `~/Temp/yt-cookies.txt`，将其中的全部内容复制粘贴到你的 Yattee 服务端后台即可！
*(注：如果命令最后报错 `No video formats found`，这是因为 yt-dlp 缺少 JS 引擎解析视频流导致的，**直接无视它**，因为我们需要的 Cookie 已经在报错前被成功导出了！)*
