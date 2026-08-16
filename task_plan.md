# 任务计划：尼康 iOS 遥控拍摄测试软件

## 目标
交付一套完整、可编译的 iOS 测试应用源码 + 构建文档：通过 Wi-Fi PTP/IP 直连尼康 Z 系列相机，实现完整参数控制（光圈/快门/ISO 等）、远程拍摄、照片/视频无损下载并自动存入系统相册（NEF/RAW 无损）。

## 当前阶段
阶段 5（已完成，待 Mac 上编译真机验证）

## 各阶段

### 阶段 1：需求与发现
- [x] 理解用户意图（远程拍摄 + 无损自动上传）
- [x] 确定约束条件（只有 Windows，无 Mac；Z 系列；完整参数控制；NEF/RAW）
- [x] 研究确认 PTP/IP 握手与尼康 Z 系列协议细节
- [x] 将发现记录到 findings.md
- **状态：** complete

### 阶段 2：规划与结构
- [x] 确定技术方案（SwiftUI + 原生 BSD socket PTP/IP）
- [x] 创建项目结构（XcodeGen project.yml）
- [x] 记录决策及理由
- **状态：** complete

### 阶段 3：实现
- [x] PTP/IP 协议层（会话/命令/事件/数据包）
- [x] 尼康相机控制层（参数读写/拍摄）
- [x] 相机发现 + Wi-Fi 连接
- [x] 照片/视频无损下载 + 自动存相册
- [x] SwiftUI 界面
- **状态：** complete

### 阶段 4：测试与验证
- [x] 静态审查代码（类型一致性、线程安全、协议正确性）
- [x] 将审查结果记录到 progress.md
- [x] 修复发现的问题（详见 progress.md 错误日志）
- **状态：** complete

### 阶段 5：交付
- [x] 检查所有输出文件
- [x] 确保 README 构建步骤完整可执行
- [x] 交付给用户
- **状态：** complete

## 关键问题
1. iOS 无法在 Windows 上编译 → 提供 XcodeGen project.yml + README，用户在 Mac 上一条命令生成工程
2. 相机 WiFi 会中断手机上网 → 文档中说明
3. 后台自动上传受 iOS 限制 → 前台自动上传 + 说明

## 已做决策
| 决策 | 理由 |
|------|------|
| SwiftUI + 原生 BSD socket 实现 PTP/IP | 无需第三方库，可控性强，可测试 |
| XcodeGen 生成 .xcodeproj | Windows 上无法生成 pbxproj，XcodeGen 可在 Mac 上一键生成 |
| 用 NEHotspotConfiguration 自动连接相机 WiFi | 也支持手动连接，双保险 |
| 监听 ObjectAdded 事件 + 轮询对象列表实现自动下载 | 事件驱动 + 兜底轮询，可靠 |
| 跳过实时取景(EVF) | 尼康 EVF 为私有扩展且复杂，作为后续扩展 |
| 用 GetDevicePropDesc 枚举参数有效值 | 避免不同相机编码差异，保证参数正确 |

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
|      |         |         |

## 备注
- 阶段状态：pending → in_progress → complete
- 做重大决策前重新读取此计划
- 记录所有错误，避免重复
