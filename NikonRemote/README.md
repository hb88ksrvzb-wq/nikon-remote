# 尼康遥控拍摄测试软件 (NikonRemote)

一个 iOS 测试应用：通过 Wi-Fi 使用 **PTP/IP 协议直连尼康 Z 系列相机**，支持：

- 远程拍摄（快门触发）
- 完整曝光参数控制：**光圈 / 快门 / ISO / 白平衡**（依赖相机 PTP 属性）
- 视频录制开始/停止（尼康 0x920A/0x920B）
- 照片/视频**无损**自动上传到系统相册（NEF/RAW 原样保存，不压缩）
- Bonjour 自动发现 `_ptp._tcp` 相机 + 手动 IP 连接兜底
- 相机 Wi-Fi 一键接入（NEHotspotConfiguration）

> 完全基于公开的 PTP/PTP-IP（ISO 15740）协议实现，线格式参照开源实现 gphoto2（libgphoto2/camlibs/ptp2），
> gphoto2 对尼康 Z6/Z7 已有专门适配，方案可行。

---

## 重要前提

1. **必须在 macOS 上编译**（iOS 开发只能使用 Xcode）。
   本仓库无法在 Windows 上生成 Xcode 工程，但所有源码已就绪，拿到 Mac 后按下面步骤 5 分钟即可跑起来。
2. **需要一台真实 iPhone**（模拟器不支持 Wi-Fi 热点配置与本地网络权限，也无法接入相机 Wi-Fi）。
3. **相机需要支持 Wi-Fi 遥控拍摄**。尼康 Z6 / Z7 / Z8 / Z9 等 Z 系列均可。
4. 连接相机 Wi-Fi 后**手机会暂时无法上网**，这是正常现象。

---

## 一、在 Mac 上构建（XcodeGen 方式，推荐）

### 1. 安装依赖

需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用来自动生成 Xcode 工程，避免手写 `.xcodeproj`）：

```bash
brew install xcodegen
```

如果没装 Homebrew，可改用「手动方式」见下文。

### 2. 生成工程并打开

```bash
cd NikonRemote
xcodegen generate
open NikonRemote.xcodeproj
```

### 3. 配置签名

1. 打开工程后选中 `NikonRemote` target
2. `Signing & Capabilities` → 勾选自己的 **Team**
3. 确认 `Product Bundle Identifier`（如 `com.jiangcheng.nikonremote`）不与其他 App 冲突

> Hotspot Configuration 与 Wi-Fi info 权限已通过 `NikonRemote/NikonRemote.entitlements` 配置。

### 4. 运行

用 **iPhone 真机**连接 Mac，点击 Run。

首次运行时系统会依次弹出权限请求：
- **本地网络**（用于发现与连接相机）→ 允许
- **照片** → 选择「添加照片」（add-only）
- **加入 Wi-Fi**（使用相机 Wi-Fi 辅助时）→ 允许

---

## 二、在 Mac 上构建（手动方式，不装 XcodeGen）

如果你不想安装 XcodeGen：

1. 打开 Xcode → `File` → `New` → `Project` → `App`
2. 把 `NikonRemote/NikonRemote/` 目录下的所有 `.swift` 文件拖入 target
3. 在 `Info.plist` 中添加（可参考 `NikonRemote/Info.plist`）：
   - `NSLocalNetworkUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
   - `NSBonjourServices` = `["_ptp._tcp"]`
   - `NSAppTransportSecurity` → `NSAllowsLocalNetworking = true`
4. `Signing & Capabilities` 中启用 **Hotspot Configuration** capability
   （或直接使用提供的 `NikonRemote/NikonRemote.entitlements` 作为 entitlements 文件）
5. 配置 Team 签名后运行。

---

## 三、使用步骤（与相机配合）

1. **相机端**：进入菜单 → 「无线连接 / Wi-Fi」→ 选择「**遥控拍摄**（Remote Photography）」→ 开启 Wi-Fi。
   - 相机屏幕会显示 **SSID 和密码**（如 `NIKON_Z6_xxxxxx`）。
2. **手机端**：
   - 方式 A（推荐）：在 App「连接」页 →「相机 Wi-Fi 辅助」填入 SSID/密码 → 点「自动加入」。
   - 方式 B：到 iOS「设置 → Wi-Fi」手动加入相机网络。
3. 回到 App「连接」页：
   - 自动发现：点「刷新」，等待出现相机条目，点击即可连接。
   - 手动兜底：相机 IP 一般为 `192.168.1.1`，填入后点「连接」。
4. 连接成功后：
   - 「遥控」页：调整 **光圈/快门/ISO/白平衡**，点中间大按钮拍摄。
   - 「传输」页：打开「**自动上传新照片/视频**」开关，之后拍摄的新文件会自动以原始格式存入系统相册。

> **自动上传说明**：iOS 不允许 App 在后台长期保持网络连接，因此「自动上传」在 App **保持前台**时实时生效；
> 回到 App 后可用「立即下载全部文件」补传漏掉的文件。传输的文件为相机原始文件（NEF/MOV 等），
> 通过 `PHAssetCreationRequest` 原样导入，**无损、不压缩**。

---

## 四、常见问题（FAQ）

| 现象 | 原因与解决 |
|------|-----------|
| 搜索不到相机 | 确认相机 Wi-Fi 已开启且 iPhone 已加入相机网络；本地网络权限需「允许」；用「手动 IP」兜底 |
| 连接超时 | 相机可能正被 SnapBridge 或其他设备占用；重启相机 Wi-Fi 后重试 |
| 参数不能设置 | 把相机拨盘调到 **M 手动档**；部分参数在 P/A/S 档会被相机拒绝 |
| 拍完没有自动上传 | 确认「传输」页开关已打开且 App 在前台；可点「立即下载全部文件」补传 |
| 视频无法保存 | 检查相册权限是否为「添加照片」；相机视频编码为 HEVC/H.264 均支持 |
| 相机自动断线 | Wi-Fi 信号弱或相机进入省电休眠；保持相机与手机距离近一些 |

### 协议层排错

如果连接不成功，可在 `CameraManager.swift` 中把：

```swift
session.onEvent = ...
session.onDisconnect = ...
```

上方加一行日志，或把 `PTPIPSession.connect` 中的 `useInitiationPacket: false` 改为 `true` 再试
（部分老固件可能要求先发 1280 字节初始化包）。

---

## 五、项目结构

```
NikonRemote/
├── project.yml                    # XcodeGen 工程定义
├── README.md
└── NikonRemote/
    ├── NikonRemoteApp.swift       # App 入口
    ├── Info.plist                 # 权限与 Bonjour 声明
    ├── NikonRemote.entitlements   # Hotspot Configuration 等能力
    ├── Core/
    │   ├── ByteBuffer.swift       # 小端字节读写
    │   └── PTPTypes.swift         # PTP 操作码/响应/事件/属性/数据集解析
    ├── PTPIP/
    │   └── PTPIPSession.swift     # PTP/IP 会话：握手/命令/数据/事件（BSD socket）
    ├── Camera/
    │   ├── NikonCamera.swift      # 尼康高层操作
    │   └── CameraDiscovery.swift  # Bonjour 发现
    ├── Services/
    │   ├── WifiJoiner.swift       # NEHotspotConfiguration 自动加 Wi-Fi
    │   ├── PhotoLibrarySaver.swift# 无损存相册
    │   └── CameraManager.swift    # 中央状态管理器
    └── Views/
        ├── RootView.swift         # Tab 容器
        ├── ConnectionView.swift   # 连接页
        ├── RemoteView.swift       # 遥控拍摄页
        └── TransferView.swift     # 传输页
```

---

## 六、已知限制

- **无实时取景预览**：尼康 EVF 使用私有扩展协议，未在本测试版实现（作为后续扩展方向）。
- **后台自动上传受限**：受 iOS 后台机制限制，自动上传仅在前台可靠。
- **无官方 SDK**：本应用不使用尼康付费 SDK，仅用公开 PTP/IP 协议，功能以协议支持为准。
