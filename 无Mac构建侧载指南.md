# 无 Mac 构建并侧载到 iPad 完整指南

用 **GitHub Actions 云端编译 + Windows 侧载（Sideloadly）**，不需要 Mac，也不需要 Xcode。

> 原理：把代码推到 GitHub → 云端 macOS 编译出未签名 `.ipa` → 在 Windows 上用 Sideloadly 用你的 Apple ID 签名并装到 iPad。

---

## 你需要准备

| 项目 | 说明 |
|------|------|
| GitHub 账号 | 免费即可 |
| Apple ID | 免费即可（**7 天有效期**，每周重签）；付费开发者 $99/年可延到一年 |
| iPad | 用于安装运行 |
| USB 数据线 | 连接 iPad 和 Windows 电脑 |
| Windows 电脑 | 你现在的这台 |

---

## 第一步：把代码推到 GitHub

本机已装 `gh`（GitHub CLI）。在项目根目录 `C:\Users\21137\Desktop\project1` 打开 PowerShell，执行：

```powershell
# 1. 登录 GitHub（浏览器授权）
gh auth login

# 2. 创建仓库并推送（按提示选 GitHub.com、HTTPS、public/private 均可）
gh repo create nikon-remote --public --source=. --remote=origin --push
```

完成后代码和 `.github/workflows/build-ios.yml` 就都在 GitHub 上了。

> 如果 `gh auth login` 交互卡住，也可以手动：去 github.com 新建一个空仓库，然后：
> ```powershell
> git remote add origin https://github.com/你的用户名/nikon-remote.git
> git branch -M master
> git push -u origin master
> ```

---

## 第二步：云端编译出 IPA

工作流已配置为 **push 到 master 就自动触发**。

1. 打开 GitHub 仓库 → **Actions** 标签页，看到 `Build iOS IPA` 在运行（约 5–8 分钟）。
2. 跑完后点进该次运行，页面底部 **Artifacts** 区域下载 `NikonRemote-ipa`（一个 zip）。
3. 解压得到 `NikonRemote.ipa`。

> 想手动重跑：仓库 → Actions → 选中工作流 → **Run workflow**。

---

## 第三步：Windows 上装 Sideloadly

1. 安装 **Apple 设备驱动**（二选一）：
   - 微软商店安装 **「Apple Devices」** 应用；或
   - 安装 [iTunes](https://www.apple.com/itunes/)（旧版，从 Apple 官网下载）。
2. 下载并安装 **Sideloadly**（https://sideloadly.io/ ），一路下一步。

---

## 第四步：签名并安装到 iPad

1. 用 USB 线把 iPad 连到电脑，iPad 上点「**信任此电脑**」并输入锁屏密码。
2. 打开 Sideloadly：
   - 顶部 **Apple ID** 填你的 Apple ID（免费账号会走「自动签名」，密码用**App 专用密码**或按提示）
   - 把上一步解压出的 `NikonRemote.ipa` **拖进 Sideloadly 窗口**
   - 确认 **iDevice** 选中了你的 iPad
3. 点 **Start**，等它签名并安装（首次会让你验证 Apple ID，可能弹验证码）。
4. 装好后，在 iPad 上：
   - **设置 → 通用 → VPN 与设备管理 → 开发者 App**，点你的 Apple ID → **信任**。
5. 回到主屏点开「尼康遥控」即可。

> 免费账号：App 只有 **7 天有效期**，到期前需重新连电脑用 Sideloadly 重签一次；也可在 Sideloadly 里开启「自动刷新」。
> 免费账号无法提供「热点配置」权限，所以 App 里「**自动加入相机 Wi-Fi**」会失效——不影响其它功能，请用**手动连接 Wi-Fi**（见下）。

---

## 第五步：连相机（免费账号请手动连 Wi-Fi）

1. 相机菜单开 Wi-Fi →「**遥控拍摄**」模式，记下相机显示的 **SSID**。
2. iPad 手动进「设置 → Wi-Fi」加入相机的网络（免费账号无法由 App 自动加入）。
3. 打开 App →「连接」页 → **手动连接** 填相机 IP（一般是 `192.168.1.1`）→ 点连接。
4. 连接成功后在「遥控」页拍照片、调参数；「传输」页开自动上传即可无损存 NEF/视频到相册。

首次运行系统会弹权限：**本地网络**（允许）、**照片**（选「添加照片」）。

---

## 常见问题

| 现象 | 解决 |
|------|------|
| Actions 编译失败 | 进 Actions 看日志；常见是 runner 版本问题，把 `.github/workflows/build-ios.yml` 里 `macos-15` 改成 `macos-14` 再重跑 |
| Sideloadly 识别不到 iPad | 确认已装 Apple Devices/iTunes 驱动、数据线可传输、iPad 已「信任此电脑」 |
| 安装失败（签名错误） | 免费 Apple ID 需用 App 专用密码；或换个 Apple ID |
| 7 天后打不开 | 重连电脑用 Sideloadly 再 Start 一次即可 |
| 连不上相机 | 确认 iPad 已加入相机 Wi-Fi、相机 IP 正确、相机未被 SnapBridge 占用 |
