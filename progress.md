# 进度日志

## 会话：2026-08-16

### 阶段 1：需求与发现
- **状态：** complete
- 执行的操作：
  - 与用户确认需求：只有 Windows、Z 系列、完整参数控制、NEF/RAW 无损
  - 抓取并阅读 gphoto2 源码（camlibs/ptp2/ptpip.c、ptpip-private.h、ptp.h、ptp.c、ptp-pack.c、PTPIP.TXT）
  - 确认 PTP/IP 线协议字节级细节并记录到 findings.md
- 创建/修改的文件：
  - task_plan.md、findings.md、progress.md

### 阶段 2：规划与结构
- **状态：** complete
- 执行的操作：
  - 选定方案：SwiftUI + 原生 BSD socket 实现 PTP/IP，XcodeGen 生成工程
- 创建/修改的文件：
  - NikonRemote/project.yml、NikonRemote/NikonRemote/Info.plist、NikonRemote/NikonRemote/NikonRemote.entitlements

### 阶段 3：实现
- **状态：** complete
- 创建/修改的文件：
  - NikonRemote/README.md
  - NikonRemote/NikonRemote/NikonRemoteApp.swift
  - NikonRemote/NikonRemote/Core/ByteBuffer.swift、PTPTypes.swift
  - NikonRemote/NikonRemote/PTPIP/PTPIPSession.swift
  - NikonRemote/NikonRemote/Camera/NikonCamera.swift、CameraDiscovery.swift
  - NikonRemote/NikonRemote/Services/WifiJoiner.swift、PhotoLibrarySaver.swift、CameraManager.swift
  - NikonRemote/NikonRemote/Views/RootView.swift、ConnectionView.swift、RemoteView.swift、TransferView.swift

### 阶段 4：测试与验证（静态审查）
- **状态：** complete
- 执行的操作：
  - 通读全部 17 个文件，检查协议字段、类型一致性、线程安全
  - 修复问题（见错误日志）

## 测试结果
| 测试 | 输入 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 静态审查（无法在 Windows 编译，需 Mac 验证） | 全部源码 | 语法/逻辑一致 | 已审查修复 | 待真机验证 |

## 错误日志
| 时间戳 | 错误 | 尝试次数 | 解决方案 |
|--------|------|---------|---------|
| 阶段3 | connect() 中 session 变量在 catch 作用域不可见 | 1 | 改为外层 var newSession: PTPIPSession? |
| 阶段3 | 空闲时命令读循环阻塞导致 30s 误断连 | 1 | 无命令在途时仅 sleep 轮询，不阻塞读 |
| 阶段3 | 事件通道空闲读超时误断连 | 1 | 事件通道用无限阻塞读（timeout=nil），close() 会唤醒 |
| 阶段3 | waitSemaphore 与发送命令的竞态 | 1 | waitSemaphore 在发送命令前设置 |
| 阶段3 | 连接竞态：断连后旧 Task 可能接管 | 1 | connectToken(UUID) 校验，过期任务直接放弃 |
| 阶段3 | DPD 属性码误按 4 字节解析 | 1 | 依据 gphoto2 ptp_unpack_DPD 改为 16 位线格式 |
| 阶段3 | SwiftUI Section 嵌套结构错误 | 1 | 拆分为独立 Section |
| 阶段3 | .help() 为 macOS 专属修饰符 | 1 | 改为在行内显示错误文本 |
| 阶段3 | 响应码未知时解析返回 nil 致误报 | 1 | 改为保留 rawCode，未知码按 GeneralError |
| 阶段3 | @MainActor 方法被后台队列闭包调用 | 1 | 相关静态/实例方法标记 nonisolated |
| 阶段3 | 非阻塞 socket 未恢复阻塞致读取立即失败 | 1 | connect 成功后清除 O_NONBLOCK，改用 select 超时读 |
| 阶段3 | 事件自动下载误处理无句柄的事件码 | 1 | 仅 ObjectAdded / Nikon ObjectAddedInSDRAM 触发 |

## 五问重启检查
| 问题 | 答案 |
|------|------|
| 我在哪里？ | 阶段 5 完成 |
| 我要去哪里？ | 用户在 Mac 上编译验证 |
| 目标是什么？ | iOS 尼康遥控拍摄测试软件源码+文档 |
| 我学到了什么？ | 见 findings.md |
| 我做了什么？ | 见上方记录 |

---
*每个阶段完成后或遇到错误时更新此文件*
